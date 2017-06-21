# -*- coding: utf-8 -*-

require 'json'
require 'rdf/vocab'
require 'csv'
require_relative 'zip_file_generator'
require 'bagit'

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

    attr_reader :id, :submitter, :in_archive, :withdrawn, :last_modified, :owning_collection, :bundle, :metadata_fields, :department, :division, :organization

    def initialize(id, options = {})

      @id = id
      @submitter = options.fetch(:submitter, nil)
      @in_archive = options.fetch(:in_archive, false)
      @withdrawn = options.fetch(:withdrawn, false)
      @last_modified = options.fetch(:last_modified, DateTime.new)
      @owning_collection = options.fetch(:owning_collection, nil)
      
      @organization = options.fetch(:organization, [])
      @department = options.fetch(:department, [])
      @division = options.fetch(:division, [])

      @bundle = options.fetch(:bundle, [])
      @metadata_fields = options.fetch(:metadata_fields, [])

      if @owning_collection
        @owning_collection.items << self
        @department = @owning_collection.communities.fetch(:dept, @department)
        @division = @owning_collection.communities.fetch(:div, @division)
      end
    end

    def to_json()

      bundle_h = @bundle.map { |bitstream| { :id => bitstream.id, :name => bitstream.name } }
      metadata_fields_h = @metadata_fields.map { |field| { :element => field.element, :qualifier => field.qualifier, :value => field.value } }

      {:id => @id,
       :bundle => bundle_h,
       :metadata_fields => metadata_fields_h
      }.to_json
    end

    def self.transform_metadata_attr(element, qualifier)

      crosswalk = {
        :creator => ::RDF::Vocab::DC11.creator,
        :contributor => ::RDF::Vocab::DC11.contributor,
        :spatial => ::RDF::Vocab::DC.spatial,
        :temporal => ::RDF::Vocab::DC.temporal,
        :date => ::RDF::Vocab::DC11.date,
        :copyright => ::RDF::Vocab::DC.dateCopyrighted,
        :submitted => ::RDF::Vocab::DC.dateSubmitted,
        :available => ::RDF::Vocab::DC.available,
        :created => ::RDF::Vocab::DC.created,
        :issued => ::RDF::Vocab::DC.issued,
        :description => ::RDF::Vocab::DC11.description,
        :abstract => ::RDF::Vocab::DC.abstract,
        :provenance => ::RDF::Vocab::DC.provenance,
        :format => ::RDF::Vocab::DC.format,
        :medium => ::RDF::Vocab::DC.medium,
        :extent => ::RDF::Vocab::DC.extent,

        :identifier => ::RDF::Vocab::DC.identifier,
        :language => ::RDF::Vocab::DC11.language,
        :hasVersion => ::RDF::Vocab::DC.hasVersion,
        :isreplacedby => ::RDF::Vocab::DC.isReplacedBy,
        :replaces => ::RDF::Vocab::DC.replaces,
        :requires => ::RDF::Vocab::DC.requires,
        :isversionof => ::RDF::Vocab::DC.isVersionOf,
        :ispartof => ::RDF::Vocab::DC.isPartOf,
        :isformatof => ::RDF::Vocab::DC.isFormatOf,
        :haspart => ::RDF::Vocab::DC.hasPart,
        :relation => ::RDF::Vocab::DC11.relation,

        :publisher => ::RDF::Vocab::DC11.publisher,
        :rights => ::RDF::Vocab::DC.rights,
        :rightsholder => ::RDF::Vocab::DC.rightsHolder,
        :source => ::RDF::Vocab::DC.source,
        :subject => ::RDF::Vocab::DC11.subject,
        :title => ::RDF::Vocab::DC.title,
        :type => ::RDF::Vocab::DC.type,
        :embargo => 'http://projecthydra.org/ns/auth/acl#hasEmbargo'
      }

      if crosswalk.has_key? qualifier.to_sym
        crosswalk[qualifier.to_sym]
      elsif crosswalk.has_key? element.to_sym
        crosswalk[element.to_sym]
      else
        raise NotImplementedError.new "#{element}.#{qualifier} is not a supported metadata attribute"
      end
    end

    def transform_metadata
      metadata_attr = @metadata_fields.map do |field|
        [ Item.transform_metadata_attr(field.element, field.qualifier).to_s, field.value ]
      end

      metadata = Hash[metadata_attr]
      metadata[RDF::URI("http://vivoweb.org/ontology/core#Department").to_s] = @department
      metadata[RDF::URI("http://vivoweb.org/ontology/core#Division").to_s] = @division
      metadata[RDF::URI("http://vivoweb.org/ontology/core#Organization").to_s] = @organization

      metadata
    end

    def export_metadata_csv(path: nil)
      metadata = transform_metadata

      tmp_dir_path = File.join(File.dirname(__FILE__), 'tmp')
      if path.nil?
        FileUtils.mkdir(tmp_dir_path) unless Dir.exist?(tmp_dir_path)
        path = File.join(tmp_dir_path, "#{@id}_metadata.csv")
      end

      ::CSV.open(path, 'wb', write_headers: true, headers: ['predicate', 'object']) do |csv|
        metadata.each_pair do |predicate, object|
          csv << [predicate, object]
        end
      end

      FileUtils.rm_r(tmp_dir_path) if Dir.exist?(tmp_dir_path)
    end

    def bag(path: nil)
      if path.nil?
        path = File.join(File.dirname(__FILE__), "#{@id}.zip")
      end

      tmp_dir_path = File.join(File.dirname(path), 'tmp')
      FileUtils.mkdir(tmp_dir_path) unless Dir.exist?(tmp_dir_path)
      csv_path = File.join(File.dirname(tmp_dir_path), "#{@id}_metadata.csv")
      
      export_metadata_csv(path: csv_path)

      bag = ::BagIt::Bag.new tmp_dir_path
      bag.add_file(File.basename(csv_path), csv_path)

      # Add the file(s) from the bundle
      @bundle.each do |bitstreams|
        bag.add_file(File.basename(bitstream.file), bitstream.file)
      end

      bag.manifest!

      # Compress the Bag
      zf = ZipFileGenerator.new(tmp_dir_path, path)
      zf.write()

      FileUtils.rm(csv_path)
      FileUtils.rm_r(tmp_dir_path) if Dir.exist?(tmp_dir_path)
    end
  end
end
