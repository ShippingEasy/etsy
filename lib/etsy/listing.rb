module Etsy

  # = Listing
  #
  # Represents a single Etsy listing.  Has the following attributes:
  #
  # [id] The unique identifier for this listing
  # [title] The title of this listing
  # [description] This listing's full description
  # [view_count] The number of times this listing has been viewed
  # [url] The full URL to this listing's detail page
  # [price] The price of this listing item
  # [currency] The currency that the seller is using for this listing item
  # [quantity] The number of items available for sale
  # [tags] An array of tags that the seller has used for this listing
  # [materials] Any array of materials that was used in the production of this item
  #
  # Additionally, the following queries on this item are available:
  #
  # [active?] Is this listing active?
  # [removed?] Has this listing been removed?
  # [sold_out?] Is this listing sold out?
  # [expired?] Has this listing expired?
  # [alchemy?] Is this listing an Alchemy item? (i.e. requested by an Etsy user)
  #
  class Listing

    include Etsy::Model

    STATES = %w(active removed sold_out expired alchemy)
    VALID_STATES = [:active, :expired, :inactive, :sold_out, :featured]

    attribute :id, :from => :listing_id
    attribute :view_count, :from => :views
    attribute :created, :from => :creation_tsz
    attribute :currency, :from => :currency_code
    attribute :ending, :from => :ending_tsz

    attributes :title, :description, :state, :url, :price, :quantity,
               :tags, :materials

    # Retrieve one or more listings by ID:
    #
    #   Etsy::Listing.find(123)
    #
    # You can find multiple listings by passing an array of identifiers:
    #
    #   Etsy::Listing.find([123, 456])
    #
    def self.find(*identifiers_and_options)
      self.find_one_or_more('listings', identifiers_and_options)
    end

    # Retrieve listings for a given shop.
    # By default, pulls back the first 25 active listings.
    # Defaults can be overridden using :limit, :offset, and :state
    #
    # Available states are :active, :expired, :inactive, :sold_out, and :featured
    # where :featured is a subset of the others.
    #
    # options = {
    #   :state => :expired,
    #   :limit => 100,
    #   :offset => 100,
    #   :token => 'toke',
    #   :secret => 'secret'
    # }
    # Etsy::Listing.find_all_by_shop_id(123, options)
    #
    def self.find_all_by_shop_id(shop_id, options = {})
      state = options.delete(:state) || :active

      raise(ArgumentError, self.invalid_state_message(state)) unless self.valid? state

      return self.sold_listings(shop_id, options) if state == :sold_out
      return self.get_all("/shops/#{shop_id}/listings/#{state}", options)
    end

    # The collection of images associated with this listing.
    #
    def images
      @images ||= Image.find_all_by_listing_id(id)
    end

    # The primary image for this listing.
    #
    def image
      images.first
    end

    STATES.each do |state|
      define_method "#{state}?" do
        self.state == state.sub('_', '')
      end
    end

    # Time that this listing was created
    #
    def created_at
      Time.at(created)
    end

    # Time that this listing is ending (will be removed from store)
    #
    def ending_at
      Time.at(ending)
    end

    private

    def self.valid?(state)
      VALID_STATES.include?(state)
    end

    def self.invalid_state_message(state)
      "The state '#{state}' is invalid. Must be one of #{VALID_STATES.join(', ')}"
    end

    def self.sold_listings(shop_id, options = {})
      response = Request.get("/shops/#{shop_id}/transactions", options.merge(:fields => 'listing_id'))

      idx = [response.result].flatten.collect {|data| data['listing_id']}

      (idx.size > 0) ? self.find(idx) : []
    end

  end
end
