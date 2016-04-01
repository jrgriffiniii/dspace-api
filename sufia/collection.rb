# -*- coding: utf-8 -*-

module Sufia

  class Collection

    attr_reader :id
    attr_accessor :resource_type, :title, :creator, :contributor, :description, :tag, :rights, :publisher, :date_created, :subject, :language, :identifier, :based_near, :related_url

    def initialize(connection, options = {})

      @connection = connection

      options.each_pair do |attr, attr_val|

        instance_variable_set "@#{attr.to_s}", attr_val
      end
    end

    def create!(path = '/collections/new')

      collections_new_page = @connection.agent.get path

#      post_query = {}
#      post_query = []

      authenticity_token = ''
      response = collections_new_page.form_with(:id => 'new_collection') do |form|

        # For handling fields with single values
        {
          :resource_type => 'collection_resource_type', # multiselect widget

          :title => 'collection_title',
          :creator => 'collection_creator',

          :contributor => 'collection_contributor',
          :description => 'collection_description',
          :tag => 'collection_tag',

          :rights => 'collection_rights', # select widget

          :publisher => 'collection_publisher',
          :date_created => 'collection_date_created',
          :subject => 'collection_subject',
          :language => 'collection_language',
          :identifier => 'collection_identifier',
          :based_near => 'collection_based_near',
          :related_url => 'collection_related_url',

        }.each_pair do | attr, field_name|

          field = form.field_with :id => field_name
          # field.value = send attr

          field_value = send attr

          if field_name != 'collection_resource_type' and field_value.is_a? Array
            
            # Work-around for capturing the department within the Community/Collection structure of the Lafayette Digital Repository (LDR)
            # @todo Refactor and abstract using either a block or Proc
#            if field_name == 'collection_tag' and field_value.length > 1
              
#              field_value = field_value[2]
#            else

#              field_value = field_value.first
#            end

            field_value.each do |val|

              field_segments = field_name.split '_'
              field_suffix = field_segments[1..-1].join '_'

              form.fields << Mechanize::Form::Field.new({'name' => "collection[#{field_suffix}][]"}, val)
            end
#          end

#          field.value = field_value
          else

            field.value = field_value
          end
        end
      end.submit

#          authenticity_token_field = form.field_with :name => 'authenticity_token'
#          authenticity_token = authenticity_token_field.value

#          field_segments = field_name.split '_'
#          field_suffix = field_segments[1..-1].join '_'

          # post_query["collection[#{field_suffix}]".to_sym] = send attr

#          field_value = send( attr )
#          field_value = '' if field_value.nil?
#          post_query << ["collection[#{field_suffix}][]", field_value ]
#        end

        # post_query.merge! 'create_collection' => '', 'type' => '', 'utf8' => '✓', 'authenticity_token' => authenticity_token
        # post_query += [['create_collection', ''], ['type', ''], ['utf8', '✓'], ['authenticity_token', authenticity_token]]

        # post_query_encoded = URI.encode_www_form post_query

        # Work-around
        # post_query_encoded = post_query_encoded[1..-1]

        # @connection.agent.post '/collections', post_query_encoded
      # end

      # Retrieve the Collection ID from the response page

      # pp response
      # "Edit this Collection"
      # edit_collection_link = response.link_with(:title=> "Edit this Collection")
      edit_collection_link = response.link_with(:text => "Edit")
      edit_collection_link_url = edit_collection_link.href
      @id = edit_collection_link_url.split('/')[-2]

      self
    end

    def +(members)
      
      members.each do |member|

        files_page = @connection.agent.get "/dashboard/files"

        result = files_page.form_with(:action => '/collections/collection_replace_id') do |form|

          token_field = form.field_with( :name => 'authenticity_token' )

          post_params = {

            "_method" => "put",
            "authenticity_token" => token_field.value,
            "batch_document_ids[]" => "ldr:#{member.id}",
            'collection[members]' => 'add'
          }

          page = @connection.agent.post("/collections/ldr:#{@id}", post_params)
        end
      end

      members
    end

    def <<(member)

      self.+([member]).first
    end

    def create

=begin
      authenticity_tokenT2CHuKaGQCmGSsPxr0FqLeepKuoX+DjM6JhwkFGbdxDVt52tH65oMqlroqEwd+nEom9RkfnCMVgAlGWO+g0tzw==
        collection[based_near][]test_location
      collection[contributor][]test_contributor
      collection[creator][]test_creator
      collection[date_created][...01-01-1970
                               collection[description][]test_abstract
                               collection[identifier][]test_identifier
                               collection[language][]test_language
                               collection[publisher][]test_publisher
                               collection[related_url][]test_related_url
                               collection[resource_type]...
                               collection[resource_type]...Article
                               collection[resource_type]...Journal
                               collection[rights][]http://creativecommons.org/publicdomain/zero/1.0/
                               collection[subject][]test_subject
                               collection[tag][]test_keyword1 test_keyword2
                               collection[title]test_title
                               create_collection
                               type
                               utf8✓
=end

      # application/x-www-form-urlencoded

      authenticity_token = nil
      
      based_near = ['']
      contributor = ['']
      creator = ['']
      date_created = ['']
      description = ['']
      identifier = ['']
      language = ['']
      publisher = ['']
      related_url = ['']
      resource_type = ['']
      rights = [''] # Mapped to URL's
      subject = ['']
      tag = ['']
      title = ['']

      # Work-arounds for the form

      create_collection = ''
      type = ''
      utf8 = '✓'

                               
    end
  end
end
