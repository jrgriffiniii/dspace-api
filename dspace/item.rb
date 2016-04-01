# -*- coding: utf-8 -*-

require 'json'

module DSpace

  LANGUAGE_MAP = {

    'it' => 'Italian',
    'es' => 'Spanish',
    'fr' => 'French',
    'de' => 'German',
    'en_US' => 'English',
    'en' => 'English',
    'ja' => 'Japanese',
    'other' => 'Other',
  }

  class Item

    attr_reader :id, :submitter, :in_archive, :withdrawn, :last_modified, :owning_collection, :bundle, :fields, :dept_metadata, :div_metadata

    def initialize(id, options = {})

      @id = id
      @submitter = options.fetch(:submitter, nil)
      @in_archive = options.fetch(:in_archive, false)
      @withdrawn = options.fetch(:withdrawn, false)
      @last_modified = options.fetch(:last_modified, DateTime.new)
      @owning_collection = options.fetch(:owning_collection, nil)

      @bundle = options.fetch(:bundle, [])
      @fields = options.fetch(:fields, [])

      if @owning_collection

        @owning_collection.items << self 

        @dept_metadata = {:title => @owning_collection.communities[:dept] }
        @div_metadata = { :title => @owning_collection.communities[:div] }
      end
    end

    def to_json()

      bundle_h = @bundle.map { |bitstream| { :id => bitstream.id, :name => bitstream.name } }
      fields_h = @fields.map { |field| { :element => field.element, :qualifier => field.qualifier, :value => field.value } }

      {:id => @id,
       :bundle => bundle_h,
       :fields => fields_h
      }.to_json
    end

    # Generate the metadata mapping
    def metadata

      generic_file_fields = {
        
        :title => [],
        :creator => [],
        
        :resource_type => [], # multiselect widget
        
        :contributor => [],
        :description => [],
        :abstract => [],
        :tag => [],
        
        :rights => [], # select widget
        
        :publisher => [],
        :date_created => [],

        :date_uploaded => [],
        :date_available => [],

        :subject => [],
        :language => [],
        :identifier => [],
        :based_near => [],
        :related_url => [],
        :source => [],
      }

      @fields.each do |field|
        
        field_value = []
        # field_key = field.element.to_sym
        
        if ['title', 'creator'].include? field.element
          generic_file_fields["#{field.element}".to_sym] << field.value
        elsif ['type'].include? field.element
          generic_file_fields[:resource_type] << field.value
        elsif ['subject'].include? field.element
          generic_file_fields[:tag] << field.value
        elsif ['publisher'].include? field.element
          generic_file_fields[:source] << field.value
        else
          
          # @todo Refactor as a Lambda or Proc
          if field.element == 'date'

            if field.qualifier == 'accessioned'
              
              field_key = :date_uploaded
            elsif field.qualifier == 'available'

              field_key = :date_available
            else
            
              field_key = :date_created
            end
          else
            
            field_key = field.element.to_sym
          end
          
          if not field.qualifier.nil?
            
            if field.element == 'description'
              
              # generic_file_fields[field_key] += '; ' + field.value
              # field_value = generic_file_fields[field_key] + "\r\n\r\n" + field.value
              field_key = :abstract
              field_value = field.value
            elsif field.qualifier != 'uri' and field.element == 'identifier'
              
              # generic_file_fields[field_key] += '; ' + field.value
              # field_value = generic_file_fields[field_key] + "\r\n\r\n" + field.value
              field_value = field.value
            else
              
              field_value = field.value
            end
#          elsif field.element == 'date'

            # Ensure that the date value is actually a date stamp
#            field_value = Date.parse field.value
          else
            
            # @todo Refactor
            field_value = field.value
          end
          
          if not generic_file_fields.has_key? field_key
            $stderr.puts "Warning: Could not map the field #{field_key}"
          else
            generic_file_fields[field_key] << field_value
          end
        end
      end

      generic_file_fields[:publisher] = ['Special Collections & College Archives, Lafayette College (Easton, Pa.)']
      generic_file_fields
    end

    def create_files_in!(sufia)

      sufia_files = []

      @bundle.map do |bitstream|

        generic_file_fields = {
            
            :titles => [],
            :creators => [],
            
            :resource_type => [], # multiselect widget
            
            :contributor => [],
            :description => [],
            :tag => [],
            
            :rights => [], # select widget
            
            :publisher => [],
            :date_created => [],
            :subject => [],
            :language => [],
            :identifier => [],
            :based_near => [],
            :related_url => []
        }

        # Ensure that each Object has been successfully ingested
        if sufia.object_cached? bitstream.file.path

          generic_file_id = sufia.object_id bitstream.file.path
          
          # Retrieve the PID for the Sufia Object
          generic_file = Sufia::GenericFile.new sufia, :file => bitstream.file, :id => generic_file_id
        else

          @fields.each do |field|
            
            if ['title', 'creator'].include? field.element
              
              generic_file_fields["#{field.element}s".to_sym] << field.value
              # field_key = "#{field.element}s".to_sym
              # field_value << field.value
            elsif ['type'].include? field.element
              
              generic_file_fields[:resource_type] << field.value
              # field_key = :resource_type
              # field_value << field.value
            else
              
              # @todo Refactor as a Lambda or Proc
              if field.element == 'date'
                
                field_key = :date_created
              else
                
                field_key = field.element.to_sym
              end
              
              field_value = generic_file_fields[field_key]
              
              if not field.qualifier.nil?
                
                if field.qualifier == 'iso' and field.element == 'language'
                  
                  field_value << LANGUAGE_MAP[field.value]
                elsif field.element == 'description'
                  
                  # generic_file_fields[field_key] += '; ' + field.value
                  # field_value = generic_file_fields[field_key] + "\r\n\r\n" + field.value
                  field_value << field.value
                  
                elsif field.qualifier != 'uri' and field.element == 'identifier'
                  
                  # generic_file_fields[field_key] += '; ' + field.value
                  # field_value = generic_file_fields[field_key] + "\r\n\r\n" + field.value
                  field_value << field.value
                else
                  
                  # field_value = field.value
                  field_value << field.value
                end
              else
                
                # @todo Refactor
                field_value << field.value
              end
              
              generic_file_fields[field_key] = field_value
            end
          end
          
          # Work-around
          # generic_file_fields[:description].shift if generic_file_fields[:description].length > 1 and generic_file_fields[:description].first.empty?
          
          # Ensure that the DSpace Bitstream format is preserved within the initial title value
          generic_file_fields[:titles][0] += ' (' + bitstream.format.short_description + ')'
          
          generic_file = sufia.create_generic_file bitstream.file
          
          # Time may be consumed by the uploading of the file
          sleep 1.5
          
          # Cache the PID of the newly created file
          sufia.cache bitstream.file.path, generic_file.id
          
          generic_file.edit! generic_file_fields
          generic_file.publish!
        end
        
        sufia_files << generic_file
      end

      # self
      sufia_files
    end

    # Create a Sufia Collection Object
    # @param Sufia
    #
    def create_collection_in!(sufia)

      item_collection_metadata = metadata
      item_collection_metadata[:title] = item_collection_metadata[:titles].first
      item_collection_metadata[:creator] = item_collection_metadata[:creators].first

      # Removes the additional collection name bearing simply the author name
      # Please see LDRHYDRA-16
      item_collection_metadata[:tag] = [ @owning_collection.name ]

=begin
      if @owning_collection.communities.length > 2

        collection_metadata[:tag] = [ @owning_collection.name ] + @owning_collection.communities[1..-1]
      else

        collection_metadata[:tag] = [ @owning_collection.name ] + @owning_collection.communities
      end
=end

=begin
      # Ensure that the collection hasn't been ingested yet
      if sufia.collection_cached? collection_metadata[:title]

        collection_id = sufia.collection_id collection_metadata[:title]

        # Directories for each collection contain Bags
        # Within each directory lies a text file specifying the Sufia Object ID
        collection_options = collection_metadata.merge collection_metadata, { :id => collection_id }
        collection = Collection.new self, collection_options
      else

        # Create a Sufia Collection for the DSpace Item
        collection = sufia.create_collection collection_metadata

        # Cache the PID of the Sufia Collection Object
        sufia.cache collection_metadata[:title], collection.id
      end

      # Retrieve the Collection for the department
      unless sufia.collection_cached? dept_metadata[:title]

        dept_collection = sufia.create_collection dept_metadata
        sufia.cache dept_metadata[:title], dept_collection.id
      end

      # Retrieve the Collection for the institutional division
      unless sufia.collection_cached? div_metadata[:title]

        div_collection = sufia.create_collection div_metadata
        sufia.cache div_metadata[:title], div_collection.id
      end
=end
      item_collection = sufia.collection item_collection_metadata
      dept_collection = sufia.collection dept_metadata
      div_collection = sufia.collection div_metadata

      # Ingest the DSpace Bitstream content into a set of Sufia GenericFile Objects
      generic_files = create_files_in! sufia

      # These Objects then become members of three collections:
      # * A Collection for the DSpace Item (bearing multiple bitstreams)
      # * A Collection for the departmental unit (e. g. "Biology" or "Office of Institutional Research")
      # * A Collection for the institutional division (e. g. "Academic Departments", "Administrative Content", or "Student Publications")
      #
      item_collection + generic_files
      dept_collection + generic_files
      div_collection + generic_files

      # Return the newly-ingested GenericFile Objects
      generic_files
    end

    # Method for creating GenericFile Objects within the repository
    # Defaults to simply creating GenericFile Objects within the repository without creating relation Collections
    # @todo Refactor
    def create_in!(sufia)

      create_files_in! sufia
    end
  end
end
