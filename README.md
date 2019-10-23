[![Documentation](http://img.shields.io/badge/docs-rdoc.info-blue.svg)](http://rubydoc.org/gems/ae_easy-login/frames)
[![Gem Version](https://badge.fury.io/rb/ae_easy-login.svg)](http://github.com/answersengine/ae_easy-login/releases)
[![License](http://img.shields.io/badge/license-MIT-yellowgreen.svg)](#license)

# AeEasy login module
## Description

AeEasy login is part of AeEasy gem collection. It provides an easy way to handle login and session recovery, quite useful when scraping websites with login features and expiring sessions.

Install gem:
```ruby
gem install 'ae_easy-login'
```

Require gem:
```ruby
 require 'ae_easy/login'
```

Code documentation can be found [here](http://rubydoc.org/gems/ae_easy-login/frames).

## Before you start

It is true that most user cases for `ae_easy-login` gem applies to websites with login pages and create sessions, so we will cover this scenario within our `How to use` section.

Therefore, `ae_easy-login` gem is designed to handle **ANY** kind of session recovery, even those that doesn't requires a login form `POST` by just changing the flow from:

```
login -> login_post -> restore
```

To whatever you need like for example:

```
home -> search_page -> restore
```

Here are some user case examples that can be fixed by `ae_easy-login` gem:

 * Websites that invalidate requests with fast expiring cookies created on first request.
 * Websites that generates tokens on every search (either on cookies or query_params) that are required to fetch a detail page.
 * Websites that expires session due inactivity.
 * Websites that uses complex login flows.
 * etc.

Feel confident to expirement with it until it fit all your needs.

## How to implement

Let's assume a simple project implementing `ae_easy` like the one described on [ae_easy README.md](https://github.com/answersengine/ae_easy/blob/master/README.md) that scrapers your website.

Now lets assume your website has a login page `https://example.com/login` with a session that expires before our sample project scrape job finish, causing all remaining webpages to respond `403` HTTP response code and fail... quite the problem isn't it? Well, not anymore, `ae_easy-login` gem to the rescue!

First, let's create our base module that will contain our session validation and recovery logic, for this example, we will call it `LoginEnable` :

```ruby
# ./lib/login_enable.rb

module LoginEnable
  include AeEasy::Login::Plugin::EnabledBehavior
  
  # Hook to initialize login_flow configuration.
  def initialize_hook_login_plugin_enabled_behavior opts = {}
    opts = {app_config: AeEasy::Core::Config.new(opts)}.merge opts
    @login_flow = AeEasy::Login::Flow.new opts
    @cookie = nil
  end

  # Get cookie after applying response cookie.
  # @return [String] Cookie string.
  def cookie
      return @cookie if @cookie.nil?
      
      raw_cookie = page['response_cookie'] || page['response_headers']['Set-Cookie']
      @cookie = AeEasy::Core::Helper::Cookie.update(page['headers']['Cookie'], raw_cookie)
      @cookie
    end
  
  # Validates session.
  # @return [Boolean] `true` when session is valid, else `false`.
  def valid_session?
    ['200', '404'].include? page['response_status_code'].to_s.strip
  end

  # Fix page session when session is invalid.
  # @return [Boolean] `true` when session is valid, else `false`.
  def fix_session
    return true if valid_session?
    
    login_flow.fix_session do
      save_pages [{
        'url' => 'https://example.com/login',
        'page_type' => 'login',
        'priority' => 9,
        'freshness' => Time.now.iso8601,
        'cookie' => "stl=#{salt}",
        'headers' => {
          # Add any extra header you need here
          'Cookie' => "stl=#{salt}"
        }
      }]
    end
    
    false
  end
end
```

Notice that our example `valid_session` method uses `200` and `404` HTTP response codes to validate that our session hasn't expired yet, therefore, **_this might not be the case for your website_**, so make sure to modify this method to fit your needs.

Our `fix_session` method will store any page with a failed session by creating an output so it can be restored later once we have the new active session cookie.

`fix_session` method will also mark the current session cookie as expired and **_enqueue a new `login` page with HIGH priority as long as another parser hasn't already did it to avoid duplicates_**.

`cookie` method will merge the request cookies with the response cookies, so we can be sure that the cookies are always updated when needed.

Next step is to create a simple parser that enqueue the `POST` of our login page:

```ruby
# ./parsers/login.rb

module Parsers
  class Login
    include AeEasy::Core::Plugin::Parser
    include LoginEnable
    
    def parse
      pages << {
        'url' => 'http://example.com/login',
        'page_type' => 'login_post',
        'priority' => 10,
        'method' => 'POST',
        'cookie' => cookie,
        'headers' => {
          # Add any extra header you need here
          'Cookie' => cookie
        }
      }
    end
  end
end
```

Now let's handle the login response, seed and restore any page with an expired session:

```ruby
# ./parsers/login_post.rb

module Parsers
  class LoginPost
    include AeEasy::Core::Plugin::Parser
    include LoginEnable

    def seed!
      return if login_flow.seeded?

      Seeders::Seeder.new(context: context).seed do |new_page|
        login_flow.fix_page! new_page
      end
      
      login_flow.seeded!
    end

    def parse
      login_flow.update_config(
        'cookie' => get_cookie,
        'expired' => false
      )

      # Wait for any pending fetch to be hold
      sleep 10

      login_flow.restore_held_pages
      seed!
    end
  end
end
```

Notice something interesting? that's right, the seeding happens **AFTER** we got our new active session cookie, so the pages we seed includes the session cookie. We use `login_flow.fix_page!` method to add our latest active session cookie along some internal `page['vars']` (used to handle page recovery) to our seeded pages.

**IMPORTANT:** This example assumes that `login_post` pages will never fails, but you might need to add some extra validations to make sure the login attempt was successful before restoring your pages.

**_Note:_** This example assumes that all pages to be seeded requires an active session, so we will add it to all pages we seed, but this will likely not apply to all pages to be seeded in a real life scenario, so make sure to add it only to those pages that requires an active session.

So next step is to modify our seeder so it allow the cookie inclusion by adding a `block` param that will be used by our `Parsers::LoginPost#seed!` method:

```ruby
# ./seeder/seeder.rb

module Seeder
  class Seeder
    include AeEasy::Core::Plugin::Seeder

    def seed &block
      new_page = {
        'url' => 'https://example.com/login.rb?query=food',
        'page_type' => 'search'
      }
      block.call(page) unless block.nil?
      pages << new_page
    end
  end
end
```

Now we will need to create a new seeder to seed login page:

```ruby
# ./seeder/login.rb

module Seeder
  class Login
    include AeEasy::Core::Plugin::Seeder

    def seed
      pages << {
        'url' => 'https://example.com/login',
        'page_type' => 'login',
        'priority' => 9
      }
    end
  end
end
```

Now let's modify our `./config.yaml` to add our new page types on it, as well as let us parse failed fetched pages since our example assumes that website will return `403` HTTP response code when session has expired:

```yaml
# ./config.yaml

parse_failed_pages: true

seeder:
  file: ./router/seeder.rb
  disabled: false

parsers:
  - page_type: search
    file: ./router/parser.rb
    disabled: false
  - page_type: product
    file: ./router/parser.rb
    disabled: false
  - page_type: login
    file: ./router/parser.rb
    disabled: false
  - page_type: login_post
    file: ./router/parser.rb
    disabled: false
```

And don't forget to modify `./ae_easy.yaml` to add our new routes and change our seeder so login page can be seed first instead of our old seeder:

```yaml
# ./ae_easy.yaml

router:
  parser:
    routes:
      - page_type: search
        class: Parsers::Search
      - page_type: product
        class: Parsers::Product
      - page_type: login
        class: Parsers::Login
      - page_type: login_post
        class: Parsers::LoginPost

  seeder:
    routes:
      - class: Seeder::Login
```

Now, let's will need to modify our routers as well since we modified our `ae_easy.yaml` routes and added new classes:

```ruby
# ./router/seeder.rb

require 'ae_easy/router'
require './seeder/login'

AeEasy::Router::Seeder.new.route context: self
```

```ruby
# ./router/parser.rb

require 'cgi'
require 'ae_easy/router'
require 'ae_easy/login'
require './lib/login_enable'
require './seeder/seeder'
require './parsers/search'
require './parsers/product'
require './parsers/login'
require './parsers/login_post'

AeEasy::Router::Parser.new.route context: self
```

Next, we need to include our `LoginEnable` module on every parser that requires session validation to fix any expired session request. To do this, we will be using our `LoginEnable#fix_session` function as the first thing to do on each parser's `parse` method:

```ruby
# ./parsers/search.rb

module Parsers
  class Search
    include AeEasy::Core::Plugin::Parser
    include LoginEnable

    def parse
      return unless fix_session
      
      html = Nokogiri.HTML content
      html.css('.name').each do |element|
        name = element.text.strip
        pages << {
          'url' => "https://example.com/product/#{CGI::escape name}",
          'page_type' => 'product',
          'vars' => {'name' => name}
        }
      end
    end
  end
end
```

```ruby
# ./parsers/product.rb

module Parsers
  class Product
    include AeEasy::Core::Plugin::Parser
    include LoginEnable

    def parse
      return unless fix_session

      html = Nokogiri.HTML content
      description = html.css('.description').first.text.strip
      outputs << {
        '_collection' => 'product',
        'name' => page['vars']['name'],
        'description' => description
      }
    end
  end
end
```

**_Note:_** This example asumes that all pages requires an active session, so we will add it to all parsers, but this will likely not apply to all parsers in a real life scenario since not all web pages will require session, so make sure to add it to only the parsers that needs it.

Finally, we need to make sure that every page that requires an active session is enqueued within our latest active session cookie, so we need to use `login_flow.fix_page!` method on all pages to be enqueued that applies.

As for this example, we already add it to our search pages enqueued by our seeder, so the only place left to modify is `./parsers/search.rb` parser since it enqueues `product` pages:

```ruby
# ./parsers/search.rb

module Parsers
  class Search
    include AeEasy::Core::Plugin::Parser
    include LoginEnable

    def parse
      return unless fix_session
      
      html = Nokogiri.HTML content
      html.css('.name').each do |element|
        name = element.text.strip
        new_page = {
          'url' => "https://example.com/product/#{CGI::escape name}",
          'page_type' => 'product',
          'vars' => {'name' => name}
        }
        login_flow.fix_page! new_page
        pages << new_page
      end
    end
  end
end
```

Hurray! Now you have implemented a fully functional login flow with auto recovery capabilities on your project.