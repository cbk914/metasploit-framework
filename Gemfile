source 'https://rubygems.org'
# Add default group gems to `metasploit-framework.gemspec`:
#   spec.add_runtime_dependency '<name>', [<version requirements>]
gemspec name: 'metasploit-framework'

# separate from test as simplecov is not run on travis-ci
group :coverage do
  # code coverage for tests
  gem 'simplecov', '0.18.2'
end

group :development do
  # Markdown formatting for yard
  gem 'redcarpet', '>= 3.5.1'
  # generating documentation
  gem 'yard'
  # for development and testing purposes
  gem 'pry-byebug'
  # module documentation
  gem 'octokit', '>= 4.21.0'
  # memory profiling
  gem 'memory_profiler'
  # cpu profiling
  gem 'ruby-prof', '1.4.2'
  # Metasploit::Aggregator external session proxy
  # disabled during 2.5 transition until aggregator is available
  #gem 'metasploit-aggregator'
end

group :development, :test do
  # automatically include factories from spec/factories
  gem 'factory_bot_rails', '>= 6.1.0'
  # Make rspec output shorter and more useful
  gem 'fivemat'
  # running documentation generation tasks and rspec tasks
  gem 'rake'
  # Define `rake spec`.  Must be in development AND test so that its available by default as a rake test when the
  # environment is development

  gem 'rspec-rails', '>= 4.0.2'

  gem 'rspec-rerun'

  gem 'rubocop', '>= 1.9.0'
  gem 'swagger-blocks'
=======

end

group :test do
  # Manipulate Time.now in specs
  gem 'timecop'
end
