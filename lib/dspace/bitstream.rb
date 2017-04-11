
module DSpace

  class Bitstream

    class Format

      attr_reader :mimetype, :short_description, :description

      def initialize(options = {})

        @mimetype = options.fetch(:mimetype, '')
        @short_description = options.fetch(:short_description, '')
        @description = options.fetch(:description, '')
      end
    end

    attr_reader :id, :name, :description, :user_format_description, :source, :internal_id, :file, :format

    def initialize(id, options = {})

      @id = id
      @name = options.fetch(:name, '')

      @description = options.fetch(:description, '')
      @user_format_description = options.fetch(:user_format_description, '')

      @source = options.fetch(:source, nil)

      @internal_id = options.fetch(:internal_id, nil)
      @file = options.fetch(:file, nil)

      @format = options.fetch(:format, nil)
    end
  end
end
