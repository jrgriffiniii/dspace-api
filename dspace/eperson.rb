
module DSpace

  class EPerson

    attr_reader :id, :email, :password, :firstname, :lastname, :last_active, :phone, :netid, :language

    def initialize(id, options = {})

      @id = id
      @email = options.fetch(:email, '')
      @password = options.fetch(:password, '')
      @firstname = options.fetch(:firstname, '')
      @lastname = options.fetch(:lastname, '')
      @last_active = options.fetch(:last_active, DateTime.new)

      @phone = options.fetch(:phone, '')
      @netid = options.fetch(:netid, '')

      # Can this be mapped to the Sufia User Model?
      @language = options.fetch(:language, '')
    end
  end
end
