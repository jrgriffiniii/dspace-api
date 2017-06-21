
require 'pg'
require 'fileutils'
require 'mimemagic'

module DSpace

  # PostgreSQL connection
  class Connection

    def initialize(options = {})

      connection_args = {}.merge options.reject { |k,v| k == :assetstore }

      @pg = PG.connect connection_args
      @items = {}
      @collections = {}
      @epersons = {}
      @assetstore = options.fetch(:assetstore, '/mnt/assetstore')
    end

    def metadata_fields(item_id)

      metadata_fields = []

      @pg.exec( "SELECT mdfield.element,mdfield.qualifier,mdvalue.text_value FROM metadatavalue AS mdvalue INNER JOIN metadatafieldregistry AS mdfield ON mdfield.metadata_field_id=mdvalue.metadata_field_id WHERE mdvalue.item_id=$1", [item_id] ) do |result|
      
        result.each do |row|

          metadata_fields << MetadataField.new( row['element'], row['text_value'], row['qualifier'] )
        end
      end

      metadata_fields
    end

    def bitstream(id)

      @pg.exec( "SELECT bitstream_id, name, description, user_format_description, source, internal_id", [id] ) do |result|

        result.each_row do |row|

          internal_id = row['internal_id']
          if internal_id

            assetstore = options.fetch(:assetstore, '/mnt/assetstore')
            file_path = [ internal_id[0..1], internal_id[2..3], internal_id[4..5], internal_id ].join '/'

            file = File.new File.join(File.dirname(assetstore), file_path)
          end

          bitstream = Bitstream.new( row['bitstream_id'],
                                     :name => row['name'],
                                     :description  => row['description'],
                                     :user_format_description  => row['user_format_description'],
                                     :source => row['source'],
                                     :internal_id => row['internal_id'],
                                     :file => file
                                     )

        end
      end
    end

    def bitstreams(item_id)

      bitstreams = []
      
      # @pg.exec( "SELECT bitstream.*,format.* FROM item2bundle AS i2b INNER JOIN bundle ON bundle.bundle_id=i2b.bundle_id LEFT JOIN bundle2bitstream AS b2b ON b2b.bundle_id=bundle.bundle_id INNER JOIN bitstream ON bitstream.bitstream_id=b2b.bitstream_id WHERE i2b.item_id=$1"
      @pg.exec( "SELECT bitstream.*,format.mimetype,format.short_description,format.description FROM item2bundle AS i2b INNER JOIN bundle ON bundle.bundle_id=i2b.bundle_id LEFT JOIN bundle2bitstream AS b2b ON b2b.bundle_id=bundle.bundle_id INNER JOIN bitstream ON bitstream.bitstream_id=b2b.bitstream_id INNER JOIN bitstreamformatregistry as format on bitstream.bitstream_format_id=format.bitstream_format_id WHERE i2b.item_id=$1", [item_id] ) do |result|

        result.each do |row|

          internal_id = row['internal_id']
          if internal_id
            src_file_path = File.join @assetstore, internal_id[0..1], internal_id[2..3], internal_id[4..5], internal_id

            # File extensions aren't appended to the file name
            # Generate the file extension using the MIME type
            extension = ::MimeMagic::EXTENSIONS.invert[row['mimetype']] || 'bin'
            tmp_file_path = File.join '/tmp', "#{internal_id}.#{extension}"

            # Copy the file to the temporary directory
            FileUtils.cp src_file_path, tmp_file_path

            # Use the temporary file
            file = File.new tmp_file_path
          end

          format = Bitstream::Format.new :mimetype => row['mimetype'], :short_description => row['short_description'], :description => row['short_description']

          bitstream = Bitstream.new( row['bitstream_id'],
                                     :name => row['name'],
                                     :description  => row['description'],
                                     :user_format_description  => row['user_format_description'],
                                     :source => row['source'],
                                     :internal_id => row['internal_id'],
                                     :file => file,
                                     :format => format
                                     )

          bitstreams << bitstream
        end
      end

      bitstreams
    end

    def eperson(id)

      eperson = nil
      @pg.exec( "SELECT eperson_id,email,password,firstname,lastname,last_active,phone,netid,language FROM eperson WHERE eperson_id = $1", [id.to_i] ) do |result|

        result.each do |row|

          eperson = EPerson.new( row['eperson_id'],
                                 :email => row['email'],
                                 :password => row['password'],
                                 :firstname => row['firstname'],
                                 :lastname => row['lastname'],
                                 :last_active => row['last_active'],
                                 :phone => row['phone'],
                                 :netid => row['netid'],
                                 :language => row['language']
                                 )
        end
      end
      
      eperson
    end

    def items(options = {})

      collection_name = options.fetch(:collection, nil)
      community_name = options.fetch(:community, nil)
      division = options.fetch(:division, 'Institutional Division')
      dept_depth = options.fetch(:dept_index, 1)

      items = []

      if not community_name.nil? and not collection_name.nil?

        pg_query = "SELECT item_id, submitter_id, in_archive, withdrawn, last_modified, owning_collection FROM collection AS coll LEFT JOIN community2collection AS c2c ON c2c.collection_id=coll.collection_id LEFT JOIN community2community AS comm2comm ON comm2comm.child_comm_id=c2c.community_id INNER JOIN community as comm ON comm.community_id=comm2comm.parent_comm_id LEFT JOIN item AS i ON i.owning_collection=coll.collection_id WHERE comm.name = '#{community_name}' AND item_id IS NOT NULL"
      else

        pg_query = "SELECT item_id, submitter_id, in_archive, withdrawn, last_modified, owning_collection FROM item AS i INNER JOIN collection AS c ON c.collection_id=i.owning_collection WHERE c.name = '#{collection_name}' AND item_id IS NOT NULL"
      end

      @pg.exec( pg_query ) do |result|

        result.each do |row|

          item_eperson = eperson row['submitter_id']
          item_collection = collection row['owning_collection'], division: division, dept_depth: dept_depth
          item_bitstreams = bitstreams row['item_id']
          item_fields = metadata_fields row['item_id']

          if row['last_modified'].nil?
            last_modified = DateTime.now
          else
            last_modified = DateTime.parse(row['last_modified'])
          end

          item = Item.new( row['item_id'],
                           :submitter => item_eperson,
                           :in_archive => row['in_archive'] == 't',
                           :withdrawn => row['withdrawn'] == 't',
                           :last_modified => last_modified,
                           :owning_collection => item_collection,
                           :bundle => item_bitstreams,
                           :metadata_fields => item_fields
                           )

          if not community_name.nil? and not collection_name.nil?
            items << item if item_collection.communities.include? community_name
          else
            items << item
          end
        end
      end

      items
    end

    def item(id, options = {})

      division = options.fetch(:division, 'Institutional Division')
      dept_depth = options.fetch(:dept_index, 1)

      item = nil
      @pg.exec( "SELECT item_id, submitter_id, in_archive, withdrawn, last_modified, owning_collection FROM item WHERE item_id=$1", [id] ) do |result|

        result.each do |row|

          item_eperson = eperson row['submitter_id']
          item_collection = collection row['owning_collection'], division: division, dept_depth: dept_depth
          item_bitstreams = bitstreams row['item_id']
          item_fields = metadata_fields row['item_id']

          item = Item.new( row['item_id'],
                           :submitter => item_eperson,
                           :in_archive => row['in_archive'] == 't',
                           :withdrawn => row['withdrawn'] == 't',
                           :last_modified => DateTime.parse(row['last_modified']),
                           :owning_collection => item_collection,
                           :bundle => item_bitstreams,
                           :metadata_fields => item_fields
                           )

        end
      end
      
      item
    end

    def communities(collection_id, division: 'Institutional Division', dept_index: 1)

      communities = []

      # community2collection
      @pg.exec( "SELECT comm.community_id, comm.name FROM community2collection AS c2c INNER JOIN community AS comm ON comm.community_id=c2c.community_id WHERE c2c.collection_id=$1", [collection_id] ) do |result|
        
        result.each do |row|

          # This captures the parent name of the community
          communities << row['name']

          # community2community
          @pg.exec( "SELECT comm.name FROM community2community AS c2c INNER JOIN community AS comm ON comm.community_id=c2c.parent_comm_id WHERE c2c.child_comm_id=$1", [ row['community_id'] ] ) do |c2c_result|

            c2c_result.each do |c2c_row|

              communities << c2c_row['name']
            end
          end
        end
      end

      { :dept => communities[dept_index],
        :div => division }
    end

    # Retrieve a collection
    def collection(id, division: 'Institutional Division', dept_depth: 1)

      collection = nil
      @pg.exec( "SELECT collection_id, name, short_description, introductory_text, provenance_description, license, copyright_text, side_bar_text FROM collection WHERE collection_id=$1", [id] ) do |result|

        result.each do |row|

          coll_communities = communities row['collection_id'], division: division, dept_index: dept_depth

          collection = Collection.new( row['collection_id'],
                                       :name => row['name'],
                                       :short_description => row['short_description'],
                                       :introductory_text => row['introductory_text'],
                                       :provenance_description => row['provenance_description'],
                                       :license => row['license'],
                                       :copyright_text => row['copyright_text'],
                                       :side_bar_text => row['side_bar_text'],
                                       :communities => coll_communities
                                       )
        end
      end
      
      collection
    end

    # Retrieve the unique terms (e. g. facets) for any given metadata value
    def vocabulary(element, qualifier: nil)

      terms = []

      # select distinct(v.text_value) from metadatavalue as v inner join metadatafieldregistry as r on r.metadata_field_id=v.metadata_field_id where r.element='contributor' and v.text_value != ''
      @pg.exec( "SELECT DISTINCT(v.text_value) FROM metadatavalue AS v INNER JOIN metadatafieldregistry AS r ON r.metadata_field_id=v.metadata_field_id WHERE r.element=$1 AND v.text_value != ''", [element] ) do |result|

        result.each do |row|

          terms << row['text_value']
        end
      end
      
      return terms
    end
  end
end
