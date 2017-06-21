# -*- coding: utf-8 -*-
require_relative 'spec_helper'

describe DSpace::Item do

  let(:metadata_fields) do
    field = double()
    allow(field).to receive(:element).and_return('description')
    allow(field).to receive(:qualifier).and_return('abstract')
    allow(field).to receive(:value).and_return('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas leo nunc, sodales ac consequat malesuada, elementum eget justo.')
    [field]
  end

  subject { described_class.new('01', metadata_fields: metadata_fields, division: 'Test Division', department: 'Test Department', organization: 'Test Organization') }

  describe '.transform_metadata_attr' do
    it 'transforms metadata field elements and qualifiers into predicate URIs' do
      expect(described_class.transform_metadata_attr('description', '')).to eq(::RDF::Vocab::DC11.description.to_s)
      expect(described_class.transform_metadata_attr('description', 'abstract')).to eq(::RDF::Vocab::DC.abstract.to_s)
    end
  end

  describe '#transform_metadata' do
    it 'transforms metadata fields into predicates and values into literals' do
      metadata = subject.transform_metadata
      expect(metadata).to be_a Hash
      expect(metadata['http://vivoweb.org/ontology/core#Organization']).to eq('Test Organization')
      expect(metadata['http://vivoweb.org/ontology/core#Division']).to eq('Test Division')
      expect(metadata['http://vivoweb.org/ontology/core#Department']).to eq('Test Department')
      expect(metadata[::RDF::Vocab::DC.abstract.to_s]).to eq('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas leo nunc, sodales ac consequat malesuada, elementum eget justo.')
    end
  end

  describe '#export_metadata_csv' do
    it 'exports metadata into a CSV' do
      path = File.join(File.dirname(__FILE__), "#{subject.id}_metadata.csv")
      subject.export_metadata_csv(path: path)
      expect(File.exist?(path)).to be true
    end
  end

  describe '#bag' do
    it 'generates a ZIP-compressed Bag for the Item using a path' do
      zip_path = File.join(File.dirname(__FILE__), "#{subject.id}.zip")
      subject.bag(path: zip_path)
      expect(File.exist?(zip_path)).to be true
      FileUtils.rm(zip_path)
    end
  end
end
