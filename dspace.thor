require 'thor'
require File.join(File.dirname(__FILE__), 'lib', 'dspace')

class Dspace < Thor

  desc "export_item", "Export an Item in a ZIP-compressed Bag"
  option :host, :aliases => "-h", :desc => "host", :default => 'localhost'
  option :port, :aliases => "-P", :desc => "port", :default => 5432, :type => :numeric
  option :dbname, :aliases => "-d", :desc => "database name", :default => 'dspace'
  option :user, :aliases => "-u", :desc => "user", :default => 'dspace'
  option :password, :aliases => "-p", :desc => "password", :default => 'secret'
  option :assetstore, :aliases => "-a", :desc => "asset store", :required => true
  option :item_id, :aliases => "-i", :desc => "item ID", :required => true, :type => :numeric
  option :output_dir, :aliases => "-o", :desc => "output file for the Bag", :required => true
  option :organization, :aliases => "-O", :desc => "organization for the Item", :default => 'Institution'
  option :division, :aliases => "-D", :desc => "division for the Item", :default => 'Institutional Division'
  def export_item()
    connection = DSpace::Connection.new(host: options[:host], port: options[:port], dbname: options[:dbname],
                                        user: options[:user], password: options[:password],  assetstore: options[:assetstore])
    item = connection.item(options[:item_id], organization: options[:organization], division: options[:division])
    output_path = File.join(options[:output_dir], "#{options[:item_id]}.zip")
    item.bag(path: output_path)
  end
end
