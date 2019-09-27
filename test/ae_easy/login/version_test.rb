require 'test_helper'

describe 'version' do
  it 'should have a version' do
    refute_nil AeEasy::Login::VERSION
  end
end
