# -*- coding: utf-8 -*-

require 'json'
require 'csv'

module Sufia

  default_metadata_fields_map = {

    'format' => 'resource_type',
    'type' => 'resource_type',
    'title' => 'title',
    'creator' => 'creator',
    'contributor' => 'contributor',
    'description' => 'description',
    'subject' => 'tag',
    'rights' => 'rights',
    'publisher' => 'publisher',
    'date' => 'date_created',
    'subject' => 'subject',
    'language' => 'language',
    'identifier' => 'identifier',
    'based_near' => 'based_near',
    'relation' => 'related_url'
  }

  class GenericFile

    def self.metadata_fields_map(dspace_metadata_fields, map = {})
      
      # Exclude the embargo and source fields
      sufia_file_fields = {}

      map ||= default_metadata_fields_map

      dspace_metadata_fields.each do |field|

        # Retrieve the field name
        if field.qualifier == ''

          field_name = field.element
        else

          field_name = field.element + '.' + field.qualifier
        end
        
        # Map the field
        if map.has_key?

          sufia_file_fields[ field_name ] = Curl::PostField.content field_name, field.value
        end
      end

      sufia_file_fields
    end

    attr_accessor :resource_type, :titles, :creators, :contributor, :description, :tag, :rights, :publisher, :date_created, :subject, :language, :identifier, :based_near, :related_url
    attr_reader :file, :id

    # Constructor for the GenericFile Class
    #
    # @param connection [Sufia::Connection] the connection to the Sufia repository instance
    # @param file [File] the binary file containing the datastream to be managed using the GenericFile Object
    # @param options [Hash] additional options
    def initialize(connection, options = {})

      @connection = connection

      options.each_pair do |attr, attr_val|

        # send "#{attr}=", attr_val
        instance_variable_set "@#{attr.to_s}", attr_val
      end
    end

    # Creating Objects from DSpace Bitstreams
    # Each Bitstream must be mapped to an individual Collection

    def create(path = 'files/new')

      # utf8â
      # authenticity_tokenlJ7TCsJVYBvwHhUyCRfLWGh5mXJrx6us+Kagr4cJm/EOSckfe31IAN8/dGKWIUixLb/iCYX9ojgQqrWxLJ/BLg==
      # total_upload_size0
      # relative_path
      # batch_id000000086
      # file_coming_fromlocal
      # terms_of_service1

      # Generate a POST request

      # Retrieve the authenticity token for the new Object
#      authenticity_token = nil

      # The POST request triggers a batch job
#      batch_id = nil

      # Work-arounds implemented for the form fields
#      utf8 = 'â'
#      total_upload_size = 0
#      relative_path = ''
#      file_coming_from = 'local'
#      terms_of_service = 1
      batch_id = @connection.batch_id path
      token = @connection.authenticity_token path
      file_path = File.absolute_path @file.path

      # @connection.post path, { :authenticity_token => token, :total_upload_size => 0, :relative_path => '', :batch_id => batch_id, :file_coming_from => 'local', :terms_of_service => 1, :utf8 => '✓' }, :file_1 => 'file_1.bin'
      @connection.post path, { :authenticity_token => token, :total_upload_size => '0', :relative_path => '', :batch_id => batch_id, :file_coming_from => 'local', :terms_of_service => '1', :utf8 => '✓' }, :'files[]' => file_path

    end

    def create!(path = '/files/new')

      files_new_page = @connection.agent.get path

      result = files_new_page.form_with(:id => 'fileupload') do |form|

        terms_of_service_field = form.checkbox_with :id => 'terms_of_service'
        terms_of_service_field.check

        form.file_uploads.first.file_name = @file.path
      end.submit

      # Attempt to directly parse the JSON within the body of the response
      begin

        file_upload_states = JSON.parse result.body
      rescue JSON::ParserError => json_error

        # The body of the response was unhandled as JSON
        nil
      else

        file_upload_state = file_upload_states.shift
        file_url = file_upload_state["url"]
        file_url_segments = file_url.split('/')
        @id = file_url_segments.last
      end

      self
    end

    def publish!

      path = '/files/' + @id + '/edit'
      files_edit_page = @connection.agent.get path

      # response = files_edit_page.form_with(:id => 'permission') do |form|

      #  radiobutton_open = form.radiobutton_with :id => 'visibility_open'
      #  radiobutton_open.check
      #end.submit

      files_edit_page.form_with(:action => "/files/#{@id}") do |form|

        publish_button = form.button_with :id => 'upload_submit'
        # publish_button.click
        form.click_button publish_button
      end
    end

    def delete!

      path = '/files/' + @id

      token = @connection.authenticity_token '/dashboard/files'

      @connection.agent.post path, { :_method => 'delete', :authenticity_token => token }
    end

    # Edits the metadata associated with the GenericFile Object
    #
    # @param file_id [String] ID for the Sufia Object
    # @param fields [Hash] metadata fields for the related Object
    # @return nil
    #
    def edit!(fields = {})

      # Update the state of the Object
      # @todo Refactor
      fields.each_pair do |attr_name, attr_val|

        public_send "#{attr_name}=", attr_val
      end

      path = '/files/' + @id + '/edit'
      files_edit_page = @connection.agent.get path

      response = files_edit_page.form_with(:class => 'simple_form edit_generic_file') do |form|

        # For handling multi-select widgets
        # resource_type_field = form.field_with :id => 'generic_file_resource_type'

        # Title has two fields
        # Creator has two fields
        { :titles => 'generic_file_title',
          :creators => 'generic_file_creator' }.each_pair do |attr, multiple_field_name|

          values = send attr

          # Work-around
          next unless values

          init_field = form.field_with :id => multiple_field_name

          # Work-around
          init_field.value = values.shift

          if not values.empty? and values.last.empty?

            # Work-around
            name_segments = multiple_field_name.split('_')
            term_field_name = name_segments[0..1].join('_') + "[#{name_segments[2..-1].join('_')}][]"

            # term_field = form.fields_with(:name => multiple_field_name).last
            term_field = form.fields_with(:name => term_field_name).last

            term_field.value = values.last
            # pp form
          end
        end

        # For handling fields with single values
        {
          :resource_type => 'generic_file_resource_type', # multiselect widget

          :contributor => 'generic_file_contributor',
          :description => 'generic_file_description',
          :tag => 'generic_file_tag',

          :rights => 'generic_file_rights', # select widget

          :publisher => 'generic_file_publisher',
          :date_created => 'generic_file_date_created',
          :subject => 'generic_file_subject',
          :language => 'generic_file_language',
          :identifier => 'generic_file_identifier',
          :based_near => 'generic_file_based_near',
          :related_url => 'generic_file_related_url',
        }.each_pair do | attr, field_name|

          field_value = send attr

          # if field_name != 'generic_file_resource_type' and field_value.is_a? Array
          if field_value.is_a? Array

            field_value.each do |val|

              unless val.empty?

                field_segments = field_name.split '_'
                field_suffix = field_segments[2..-1].join '_'

                # Debug
#                if field_name == 'generic_file_description'

#                  pp form
#                end

                field = form.field_with :id => field_name

                if field.value.empty?

                  field.value = val
                else
                  
                  form.fields << Mechanize::Form::Field.new({'name' => "generic_file[#{field_suffix}][]"}, val)
                end

                # Debug
#                if field_name == 'generic_file_description'

#                  pp form
#                end
              end
            end
          elsif not field_value.nil? and not field_value.empty?

            field = form.field_with :id => field_name
            field.value = field_value
          end
        end
      end.submit

      response.body
    end

    # Export Object metadata into a CSV file
    #
    # @return File
    def export_metadata(csv_file_path, fields = {})

      csv_file = File.new csv_file_path, 'ab'

      # Update the state of the Object
      # @todo Refactor
      fields.each_pair do |attr_name, attr_val|

        public_send "#{attr_name}=", attr_val
      end

      csv_columns = [

                     :titles,
                     :creators,

                     :resource_type, # multiselect widget

                     :contributor,
                     :description,
                     :tag,

                     :rights, # select widget

                     :publisher,
                     :date_created,
                     :subject,
                     :language,
                     :identifier,
                     :based_near,
                     :related_url

                    ]

      CSV.open(csv_file.path, 'ab') { |csv| csv << csv_columns }

      CSV.open(csv_file.path, 'ab') do |csv|

        row = []
        
        csv_field = ''

        # For handling multi-select widgets
        # resource_type_field = form.field_with :id => 'generic_file_resource_type'

        # Title has two fields
        # Creator has two fields
        { :titles => 'generic_file_title',
          :creators => 'generic_file_creator' }.each_pair do |attr, multiple_field_name|

#          values = public_send attr || []
          values = public_send attr
          if values.nil?

            values = []
          end

          row << values.join(';')
        end

        # For handling fields with single values
        {
          :resource_type => 'generic_file_resource_type', # multiselect widget

          :contributor => 'generic_file_contributor',
          :description => 'generic_file_description',
          :tag => 'generic_file_tag',

          :rights => 'generic_file_rights', # select widget

          :publisher => 'generic_file_publisher',
          :date_created => 'generic_file_date_created',
          :subject => 'generic_file_subject',
          :language => 'generic_file_language',
          :identifier => 'generic_file_identifier',
          :based_near => 'generic_file_based_near',
          :related_url => 'generic_file_related_url',
        }.each_pair do | attr, field_name|

          # field_value = public_send attr || []
          field_value = public_send attr
          if field_value.nil?

            field_value = ''
          end

          row << field_value
        end

        # Update the CSV file
        csv << row
      end

      csv_file
    end

    # Export the Object into a Bag for ingestion
    # @return BagIt::Bag
    def export(export_dir_path)

      # Create the metadata within a temporary directory
      metadata_file_path = File.join '/tmp', @id + '.csv'
      export_metadata metadata_file_path

#      master_file_path = File.join '/tmp', @id + '.bin'
#      File.new @, master_file_path

      bag = BagIt::Bag.new export_dir_path

      bag.add_file @id + '.csv', metadata_file_path
      bag.add_file @id + '.' + master_file_ext, @file.path

      bag
    end

    # Accessor for the file extension of the master file for the Generic Object
    # Defaults to a 'bin' if the file extension could not be determined
    # @return String
    def master_file_ext

      if @master_file_ext.nil?

        mime_type = MimeMagic.by_path(@file.path) || MimeMagic.by_magic(@file)
        @master_file_ext = MimeMagic::EXTENSIONS.invert[mime_type] || 'bin'
      end

      @master_file_ext
    end

    # Importing metadata
    def import_metadata!(csv_file_path)

      csv_columns = []
      row_i = 0

      CSV.foreach(csv_file_path) do |row|

        # csv_fields[column] = row.split ';'
        if row_i == 0

          csv_columns = row
        else

          csv_field_i = 0
          row.each do | csv_field |

            public_send "#{csv_columns[csv_field_i]}=", csv_field.split(';')
            csv_field_i += 1
          end
        end

        row_i += 1
      end
    end
    
    # Create a new Object
    def import!(import_dir_path)

      bag = BagIt::Bag.new import_dir_path
      
      file_path = bag.get @id + '.' + master_file_ext
      @file = File.new file_path
      
      metadata_file = bag.get @id + '.csv'

      import_metadata! metadata_file.path
    end
    
    
  end
end
