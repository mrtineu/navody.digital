module Apps
  module ParliamentVoteApp
    class ApplicationForm
      VOTE_DATE = Date.new(2020, 2, 29)
      DELIVERY_BY_POST_DEADLINE_DATE = VOTE_DATE - 15.days

      include ActiveModel::Model

      attr_accessor :step
      attr_accessor :place
      attr_accessor :sk_citizen
      attr_accessor :delivery
      attr_accessor :full_name, :pin
      attr_accessor :authorized_person_full_name, :authorized_person_pin
      attr_accessor :street, :pobox, :municipality
      attr_accessor :same_delivery_address
      attr_accessor :delivery_street, :delivery_pobox, :delivery_municipality, :delivery_country
      attr_accessor :municipality_email
      attr_accessor :permanent_resident

      validates_presence_of :place, message: 'Vyberte si jednu z možností', on: :place

      validates_presence_of :sk_citizen, message: 'Vyberte áno pokiaľ ste občan Slovenskej republiky', on: :sk_citizen
      validates_presence_of :permanent_resident, message: 'Vyberte áno pokiaľ máte trvalý pobyt na Slovensku', on: :permanent_resident

      validates_presence_of :delivery, message: 'Vyberte si spôsob prevzatia hlasovacieho preukazu', on: :delivery
      validates_exclusion_of :delivery, in: ['post'],
                            if: -> { Date.current > DELIVERY_BY_POST_DEADLINE_DATE },
                             message: 'Termín na zaslanie hlasovacieho preukazu poštou už uplynul.', on: :delivery

      validates_presence_of :full_name, message: 'Meno je povinná položka',
                            on: [:identity, :world_sk_permanent_resident, :authorized_person]
      validates_presence_of :pin, message: 'Rodné číslo je povinná položka',
                            on: [:identity, :world_sk_permanent_resident, :authorized_person]
      validates_presence_of :street, message: 'Zadajte ulicu alebo názov obce ak obec nemá ulice',
                            on: [:identity, :world_sk_permanent_resident, :authorized_person]
      validates_presence_of :pobox, message: 'Zadajte poštové smerové čislo',
                            on: [:identity, :world_sk_permanent_resident, :authorized_person]
      validates_presence_of :municipality, message: 'Vyberte obec',
                            on: [:identity, :world_sk_permanent_resident, :authorized_person]

      validates_presence_of :authorized_person_full_name, message: 'Meno splnomocnenej osoby je povinná položka',
                            on: [:authorized_person]
      validates_presence_of :authorized_person_pin, message: 'Rodné číslo splnomocnenej osoby je povinná položka',
                            on: [:authorized_person]

      validates_presence_of :same_delivery_address, message: 'Zadajte kam chcete zaslať hlasovací preukaz',
                            on: :delivery_address
      validates_presence_of :delivery_street, message: 'Zadajte ulicu alebo názov obce ak obec nemá ulice',
                            on: [:delivery_address, :world_sk_permanent_resident],
                            unless: -> (f) { f.same_delivery_address? }
      validates_presence_of :delivery_pobox, message: 'Zadajte poštové smerové čislo',
                            on: [:delivery_address, :world_sk_permanent_resident],
                            unless: -> (f) { f.same_delivery_address? }
      validates_presence_of :delivery_municipality, message: 'Zadajte obec',
                            on: [:delivery_address, :world_sk_permanent_resident],
                            unless: -> (f) { f.same_delivery_address? }
      validates_presence_of :delivery_country, message: 'Zadajte štát',
                            on: [:delivery_address, :world_sk_permanent_resident],
                            unless: -> (f) { f.same_delivery_address? }

      def self.active?
        VOTE_DATE >= Date.current
      end

      def minv_email
        "volby@minv.sk"
      end

      def year
        VOTE_DATE.year
      end

      def same_delivery_address?
        same_delivery_address == '1'
      end

      def full_address
        "#{street}, #{pobox} #{municipality}"
      end

      def from_slovakia_email_body
        ActionController::Base.new.render_to_string(
          partial: "apps/parliament_vote_app/application_forms/from_slovakia_email_body",
          locals: { model: self },
        )
      end

      def from_slovakia_authorized_person_email_body
        ActionController::Base.new.render_to_string(
          partial: "apps/parliament_vote_app/application_forms/from_slovakia_authorized_person_email_body",
          locals: { model: self },
        )
      end

      def world_abroad_resident_email_body
        ActionController::Base.new.render_to_string(
          partial: "apps/parliament_vote_app/application_forms/world_abroad_resident_email_body",
          locals: { model: self },
        )
      end

      def world_sk_resident_email_body
        ActionController::Base.new.render_to_string(
          partial: "apps/parliament_vote_app/application_forms/world_sk_resident_email_body",
          locals: { model: self },
        )
      end

      def run(listener)
        case step
        when 'start'
          start_step(listener)
        when 'place'
          place_step(listener)
        when 'sk_citizen'
          sk_citizen_step(listener)
        when 'delivery'
          delivery_step(listener)
        when 'identity'
          identity_step(listener)
        when 'authorized_person'
          authorized_person_step(listener)
        when 'address'
          address_step(listener)
        when 'delivery_address'
          delivery_address_step(listener)
        when 'world'
          world_step(listener)
        when 'world_sk_permanent_resident'
          world_sk_permanent_resident_step(listener)
        when 'world_sk_permanent_resident_end'
          world_sk_permanent_resident_end_step(listener)
        when 'world_abroad_permanent_resident'
          world_abroad_permanent_resident_step(listener)
        when 'world_abroad_permanent_resident_end'
          world_abroad_permanent_resident_end_step(listener)
        end
      end

      private def start_step(listener)
        self.step = 'sk_citizen'
        listener.render :sk_citizen
      end

      private def sk_citizen_step(listener)
        if valid?(:sk_citizen)
          case sk_citizen
          when 'yes'
            self.step = 'place'
            listener.render :place
          when 'no'
            listener.redirect_to action: :non_sk_nationality
          end
        else
          listener.render :sk_citizen
        end
      end

      private def place_step(listener)
        if valid?(:place)
          case place
          when 'home'
            listener.redirect_to action: :home
          when 'sk'
            listener.redirect_to action: :delivery
          when 'world'
            listener.redirect_to action: :world
          end
        else
          listener.render :place
        end
      end

      # Home flow
      private def delivery_step(listener)
        if valid?(:delivery)
          case delivery
          when 'post'
            self.step = 'identity'
            listener.render :identity
          when 'authorized_person'
            self.step = 'authorized_person'
            listener.render :authorized_person
          when 'person'
            listener.redirect_to action: :person
          end
        else
          listener.render :delivery
        end
      end

      private def identity_step(listener)
        if valid?(:identity)
          self.step = 'delivery_address'
          listener.render :delivery_address
        else
          listener.render :identity
        end
      end

      private def delivery_address_step(listener)
        if valid?(:delivery_address)
          self.step = 'send'
          listener.render :send
        else
          listener.render :delivery_address
        end
      end

      private def authorized_person_step(listener)
        if valid?(:authorized_person)
          listener.render :authorized_person_send
        else
          self.step = 'authorized_person'
          listener.render :authorized_person
        end
      end

      # World flow
      private def world_step(listener)
        if valid?(:permanent_resident)
          case permanent_resident
          when 'yes'
            self.step = 'world_sk_permanent_resident'
            listener.render :world_sk_permanent_resident
          when 'no'
            self.step = 'world_abroad_permanent_resident'
            listener.render :world_abroad_permanent_resident
          end
        else
          listener.render :world
        end
      end

      private def world_sk_permanent_resident_step(listener)
        if valid?(:world_sk_permanent_resident)
          self.step = 'world_sk_permanent_resident_end'
          listener.render :world_sk_permanent_resident_end
        else
          listener.render :world_sk_permanent_resident
        end
      end

      private def world_sk_permanent_resident_end_step(listener)
        self.step = 'world_sk_permanent_resident_end'
        listener.render :world_sk_permanent_resident_end
      end

      private def world_abroad_permanent_resident_step(listener)
        if valid?(:world_abroad_permanent_resident)
          self.step = 'world_abroad_permanent_resident_end'
          listener.render :world_abroad_permanent_resident_end
        else
          listener.render :world_abroad_permanent_resident
        end
      end

      private def world_abroad_permanent_resident_end_step(listener)
        self.step = 'world_abroad_permanent_resident_end'
        listener.render :world_abroad_permanent_resident_end
      end
    end
  end
end