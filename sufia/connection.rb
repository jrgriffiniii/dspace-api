# -*- coding: utf-8 -*-

require 'curb'
require 'nokogiri'

module Sufia

  # Wrapper class for connecting to a Sufia instance
  class Connection

    attr_reader :authenticated, :agent

    HTTP_METHODS = ['get', 'post', 'put', 'delete', 'head']
    HTTP_METHODS_UPLOAD = ['post']

    def initialize(host: 'localhost', protocol: 'http', port: 80, options: {})

      @cache = options.fetch :cache, File.join(File.path(__FILE__), 'cache')
      curb_options = options.reject { |k| k == :cache }

      @base_url = "#{protocol}://#{host}:#{port}"

      @curb_options = curb_options
      @curl = Curl::Easy.new
      @curb_options.each_pair { |attr_name, attr_val| @curl.public_send "#{attr_name}=", attr_val }

      @agent = Mechanize.new
      @agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
      @agent.get @base_url

      @authenticated = false
    end

    def request(resource, method, *params)

      raise NotImplementedError.new "HTTP method #{method} not supported" unless HTTP_METHODS.include? method

      if not resource.nil?

        path = '/' + resource
      else

        path = '/'
      end

      url = @base_url + path
      @curl.url = url

      if ['get', 'delete'].include? method

        @curl.public_send "http_#{method}".to_sym
      else

        @curl.public_send "http_#{method}".to_sym, *params
      end
      @curl
    end

    def authenticate(auth_type = 'basic', username = 'admin', password = 'secret')

#      @curb_options['user'] = username
#      @curb_options['password'] = password

      # Attempt to authenticate and raise an exception upon failure

      @curb_options['http_auth_types'] = auth_type.to_sym
      @curb_options['username'] = username
      @curb_options['password'] = password
      @curb_options['enable_cookies'] = true

      @curl.http_auth_types = :basic
      @curl.username = username
      @curl.password = password
      @curl.enable_cookies = true

      # Initiate the session with a HEAD request
      head
    end

    # Scrape the authenticity token from the forms offered for GenericFile and Collection Objects
    def authenticity_token(path)

      response = @agent.get path

      # doc = Nokogiri::HTML response.body_str
      # token_attr = doc.at_xpath('//input[@name="authenticity_token"]/@value')
      # raise NotImplementedError.new "Could not retrieve the authenticity from the following response:" + response.body_str if token_attr.nil?
      token_attr = response.at('//input[@name="authenticity_token"]/@value')

      token_attr.value
    end

    # Scrape the batch ID token from the forms offered for GenericFile Objects
    # @todo Refactor
    def batch_id(path)

      response = get path
      doc = Nokogiri::HTML response.body_str

      token_attr = doc.at_xpath('//input[@name="batch_id"]/@value')

      raise NotImplementedError.new "Could not retrieve the batch ID from the following response:" + response.body_str if token_attr.nil?
      token_attr.value
    end

    def form_authenticate(email = 'admin@localhost.localdomain', password = 'secret', path = '/users/sign_in')

      token = authenticity_token path

      # Scrape the authentication token
      # post path, :authenticity_token => token, :commit => 'Log in', :user => { :email => email, :password => password, :remember_me => 0 }, :utf8 => '✓'

      puts token

      response = post path, :authenticity_token => token, :commit => 'Log in', :'user[email]' => email, :'user[password]' => password, :remember_me => 0, :utf8 => '✓'

      puts response.body_str
      
      # @todo Refactor
      authenticated = true
      response
    end

    # Alias for the preferred method of authentication
#    def authenticate!(*params)
    def authenticate!(email = 'admin@localhost.localdomain', password = 'secret', path = '/users/sign_in')

      # form_authenticate params
      sign_in_page = @agent.get path

      @authenticated = sign_in_page.link_with(href: '/users/sign_out')

      unless @authenticated

        sign_in_page.form_with(:id => 'new_user') do |form|

          user_email_field = form.field_with(:id => 'user_email')
          user_password_field = form.field_with(:id => 'user_password')

          user_email_field.value = email
          user_password_field.value = password
        end.submit
      end
    end

    # Perform a number of tasks as an authenticated user
    def as_authenticated(tasks, email = 'admin@localhost.localdomain', password = 'secret', path = '/users/sign_in')

      # The initial authentication task
      
    end

    # Determine whether or not the Collection has been ingested into the Sufia instance
    def collection_cached?(collection_label)

      File.directory? File.join(@cache, collection_label)
    end

    def collection_id(collection_label)

      File.open( File.join(@cache, collection_label, 'pid.txt')) { |f| f.read }
    end

    def collection(collection_metadata)

      # If the Collection Object was already ingested...
      if collection_cached? collection_metadata[:title]

        collection_id = collection_id collection_metadata[:title]
        collection_options = collection_metadata.merge collection_metadata, { :id => collection_id }
        collection = Collection.new self, collection_options
      else

        # Create a Sufia Collection for the DSpace Item
        collection = create_collection collection_metadata

        # Cache the PID of the Sufia Collection Object
        cache collection_metadata[:title], collection.id
      end

      collection
    end

    # Determine whether or not the Object has been ingested into the Sufia instance
    # Unique directory names are generated from the paths of the uploaded files
    def object_cached?(file_path)

      File.directory? File.join(@cache, file_path)
    end

    # Retrieve the PID for the Object
    def object_id(file_path)

      File.open( File.join(@cache, file_path, 'pid.txt')) { |f| f.read }
    end

    # Cache an ingested Object
    def cache(key, object_pid)

      # Normalize
      # key = key.sub(/ [[:space:]] | [[:punct:]] /, '_')
      key = key.gsub(/[[:space:]]|[[:punct:]]/, '_').downcase

      Dir.mkdir File.join(@cache, key) unless Dir.exist?( File.join(@cache, key) )
      File.open( File.join(@cache, key, "pid.txt"), 'wb' ) { |f| f.write(object_pid) }
    end

    # Access GenericFile Objects within Sufia
    def generic_file(*params)

      generic_file = GenericFile.new self, *params
    end

    # Create GenericFile Objects within Sufia
    def create_generic_file(file, *args)

      generic_file = GenericFile.new self, :file => file

      # generic_file.create! *args
      generic_file.create!
    end

    # Create Collection Objects within Sufia
    def create_collection(options = {})

      collection = Collection.new self, options

      collection.create!
    end

    HTTP_METHODS_UPLOAD.each do |method|

      define_method(method) do |*params|

        # def post(resource, params = {}, files = {})
        resource, data_params = params.shift 2
        data_params ||= {}

        files = params.shift
        files ||= {}

        request_params = data_params.map { |param_name, param_val| Curl::PostField.content(param_name.to_s, param_val) }

        # Files in the POST request

        # Sent for the next request
        @curl.multipart_form_post = true unless method != 'post' or (params.empty? and files.empty?)

        files.each_pair do |file_param_name, file_path|

          request_params << Curl::PostField.file(file_param_name.to_s, file_path)
        end

        request_params += params

        request(resource, 'post', *request_params)
      end
    end

    # Easier syntax
    HTTP_METHODS.reject { |method| method == 'post'  }.each do |method|

      define_method(method) do |*params|

        resource = params.shift
        request(resource, method, *params)
      end
    end
  end
end
