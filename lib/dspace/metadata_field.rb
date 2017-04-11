
module DSpace

  class MetadataField

    attr_reader :id, :element, :qualifier, :value

    def initialize(element, value, qualifier = '')
      
      @element = element
      @qualifier = qualifier

      @value = value
    end
  end
end
