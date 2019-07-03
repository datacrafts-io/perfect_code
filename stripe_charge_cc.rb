module StripeSystem
  class CardService
    def create(token:, user:)
      return unless token

      customer = find_or_create_customer(user)
      if customer
        create_customer_card(customer, token)
      end
    rescue Stripe::StripeError => e
      stripe_error(e, 'card updating', customer.id)
    end

    def charge(card:, payment:)
      if card
        amount = Money.from_amount(
          payment.listing.payment_plan.price,
          Kontorplass::Config.billing_currency
        ).cents

        charge = Stripe::Charge.create(
          amount:               amount,
          currency:             Kontorplass::Config.billing_currency,
          customer:             payment.listing.user.stripe_customer,
          source:               card.stripe_id,
          description:          stripe_charge_description(payment),
          statement_descriptor: stripe_charge_descriptor(payment),
          metadata:             { payment_id: payment.id }
        )

        Charge.new(raw_stripe_charge: charge)
      else
        Charge.new(
          error: 'Cannot charge a customer that has no active card'
        )
      end
    rescue Stripe::StripeError => e
      stripe_error(e, 'charging', payment.listing.user.stripe_customer)
      Charge.new(error: e)
    end

    private

    def find_or_create_customer(user)
      find_customer(user) || create_customer(user)
    end

    def find_customer(user)
      if user.stripe_customer
        customer = Stripe::Customer.retrieve(id: user.stripe_customer)
      end
    rescue Stripe::InvalidRequestError,
           Stripe::AuthenticationError,
           Stripe::APIConnectionError => e
      stripe_error(e, 'retrieve', user.stripe_customer)
    rescue Stripe::StripeError; end

    def create_customer(user)
      customer = Stripe::Customer.create(
        email:        user.email,
        description:  user.name
      )
      user.update(stripe_customer: customer.id) if customer

      customer
    end

    def create_customer_card(customer, token)
      return if token.blank?
      customer.sources.create(source: token)
    end

    def stripe_error(e, act, customer_id)
      message = "Stripe error while #{act} (customer #{customer_id}): " \
        "#{e.json_body[:error]}"

      Rails.logger.error(message)

      unless e.kind_of?(Stripe::CardError)
        Airbrake.notify(e, parameters: { action: act, customer: customer_id})
      end

      false
    end

    def stripe_charge_description(payment)
      payment = payment.decorate

      I18n.t(
        'stripe.charges.description',
        plan_kind:          plan_kind(payment.payment_plan),
        amount_without_vat: payment.amount_without_vat,
        vat:                payment.vat
      )
    end

    def stripe_charge_descriptor(payment)
      "Kontorplasser #{payment.decorate.formatted_amount}".truncate(22)
    end

    def plan_kind(payment_plan)
      if payment_plan.weekly?
        I18n.t('stripe.payment_plans.weekly')
      else
        I18n.t('stripe.payment_plans.unlimited')
      end
    end
  end
end
