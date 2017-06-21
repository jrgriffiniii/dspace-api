# -*- coding: utf-8 -*-
require_relative 'spec_helper'

describe DSpace::Connection do
  subject { described_class.new assetstore: File.join(File.dirname(__FILE__), 'fixtures') }

  describe "#new" do
    before { allow(PG).to receive(:connect).with({}) }

    it 'initializes with empty connection args' do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe "#eperson" do
    before do
      pg = double('pg')
      allow(pg).to receive(:exec).and_yield([{ 'eperson_id' => 0,
                                               'email' => 'user@localhost',
                                               'password' => 'secret',
                                               'firstname' => 'John',
                                               'lastname' => 'Smith',
                                               'last_active' => nil,
                                               'phone' => '555-5555',
                                               'netid' => 'jsmith@localhost',
                                               'language' => 'en-US',
                                             }])
      allow(PG).to receive(:connect).with({}).and_return(pg)
    end

    it 'creates an EPerson instance using an ID' do
      result = subject.eperson(0)
      expect(result).to be_a(DSpace::EPerson)
    end
  end

  describe "#communities" do
    before do
      pg = double('pg')
      allow(pg).to receive(:exec).and_yield([{
                                               'name' => 'My Community'
                                             }])
      allow(PG).to receive(:connect).with({}).and_return(pg)
    end

    it 'creates a Community object using an ID' do
      result = subject.communities(0)
      expect(result).to be_a(Hash)
      expect(result).to include(:dept)
      expect(result).to include(:div)
      expect(result[:dept]).to eq('My Community')
      expect(result[:div]).to eq('Institutional Division')
    end
  end

  describe "#collection" do
    before do
      pg = double('pg')
      allow(pg).to receive(:exec).and_yield([{ 'collection_id' => 0,
                                               'name' => 'My Collection',
                                               'short_description' => '',
                                               'introductory_text' => '',
                                               'provenance_description' => '',
                                               'license' => '',
                                               'copyright_text' => '',
                                               'side_bar_text' => ''
                                             }])
      allow(PG).to receive(:connect).with({}).and_return(pg)
    end

    it 'creates a Collection object using an ID' do
      result = subject.collection(0)
      expect(result).to be_a(DSpace::Collection)
    end
  end

  describe "#bitstreams" do
    before do
      pg = double('pg')
      allow(pg).to receive(:exec).and_yield([{ 'internal_id' => '0123456',
                                               'mimetype' => 'bin',
                                               'short_description' => '',
                                               'bitstream_id' => 0,
                                               'name' => '',
                                               'description' => '',
                                               'user_format_description' => '',
                                               'source' => '',
                                             }])
      allow(PG).to receive(:connect).with({}).and_return(pg)
    end


    it 'creates Bitstream objects using an ID' do
      result = subject.bitstreams(0)
      expect(result.length).to eq(1)
      expect(result.first).to be_a(DSpace::Bitstream)
    end
  end

  describe "#metadata_fields" do
    before do
      pg = double('pg')
      allow(pg).to receive(:exec).and_yield([{
                                               'element' => 'title',
                                               'text_value' => 'My Title',
                                               'qualifier' => 'english'
                                             }])
      allow(PG).to receive(:connect).with({}).and_return(pg)
    end


    it 'creates MetadataField objects using an ID' do
      result = subject.metadata_fields(0)
      expect(result.length).to eq(1)
      expect(result.first).to be_a(DSpace::MetadataField)
    end
  end
  
  describe "#items" do
    before do
      pg = double('pg')
      allow(pg).to receive(:exec).and_yield([{'submitter_id' => 0,
                                              'owning_collection' => 0,
                                              'item_id' => 0,
                                              'last_modified' => nil,
                                              'in_archive' => 'f',
                                              'withdrawn' => 'f',
                                             },
                                             {'submitter_id' => 0,
                                              'owning_collection' => 0,
                                              'item_id' => 1,
                                              'last_modified' => nil,
                                              'in_archive' => 't',
                                              'withdrawn' => 't',
                                             }
                                            ])
      allow(PG).to receive(:connect).with({}).and_return(pg)
    end

    subject { described_class.new }
    context 'when retrieving items within a collection' do
      let(:items) { subject.items(collection: 'My Collection') }
      
      it 'creates Item objects' do
        expect(items.length).to eq(2)
        expect(items.first).to be_a(DSpace::Item)
      end
    end

    context 'when retrieving items within a collection' do
      let(:items) { subject.items(community: 'My Communities') }
      
      it 'creates Item objects' do
        expect(items.length).to eq(2)
        expect(items.first).to be_a(DSpace::Item)
      end
    end
  end
end
