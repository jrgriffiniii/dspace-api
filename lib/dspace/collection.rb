
module DSpace
  
  class Collection

    attr_reader :id, :name, :short_description, :introductory_text, :provenance_description, :license, :copyright_text, :side_bar_text, :admin, :communities
    attr_accessor :items
    
    def initialize(id, options = {})

      @id = id
      @name = options.fetch(:name, '')

      @short_description = options.fetch(:short_description, '')
      @introductory_text = options.fetch(:introductory_text, '')
      @provenance_description = options.fetch(:provenance_description, '')
      @license = options.fetch(:license, '')
      @copyright_text = options.fetch(:copyright_text, '')
      @side_bar_text = options.fetch(:side_bar_text, '')

      @admin = options.fetch(:admin, nil)

      @items = options.fetch(:items, [])

      @communities = options.fetch(:communities, nil)
    end
  end
end
