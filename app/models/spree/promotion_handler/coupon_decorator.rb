Spree::PromotionHandler::Coupon.class_eval do
  attr_reader :order

  def apply
    if order.coupon_code.present?
      if promotion.present? && promotion.actions.exists?
        handle_present_promotion
      elsif Spree::Promotion.with_coupon_code(order.coupon_code).try(:expired?)
        set_error_code :coupon_code_expired
      elsif promotion_code && promotion_code.promotion.expired?
        set_error_code :coupon_code_expired
      else
        set_error_code :coupon_code_not_found
      end
    end
    self
  end

  def promotion
    @promotion ||= promotion_code.promotion if promotion_code && promotion_code.promotion.active?
  end

  private

  def promotion_code
    @promotion_code ||= Spree::PromotionCode.where(value: order.coupon_code.downcase).first
  end

  def promotion_exists_on_order?
    order.promotions.include? promotion
  end

  def handle_present_promotion
    return promotion_usage_limit_exceeded if promotion.usage_limit_exceeded?(order) || promotion_code.usage_limit_exceeded?(order)
    return promotion_applied if promotion_exists_on_order?
    unless promotion.eligible?(order, promotion_code: promotion_code)
      self.error = promotion.eligibility_errors.full_messages.first unless promotion.eligibility_errors.blank?
      return (error || ineligible_for_this_order)
    end

    # If any of the actions for the promotion return `true`,
    # then result here will also be `true`.
    if promotion.activate(order: order, promotion_code: promotion_code)
      determine_promotion_application_result
    else
      set_error_code :coupon_code_unknown_error
    end
  end

  def determine_promotion_application_result
    # Check for applied adjustments.
    discount = order.all_adjustments.promotion.eligible.detect do |p|
      p.source.promotion.codes.any? { |code| code.value == order.coupon_code.downcase }
    end

    # Check for applied line items.
    created_line_items = promotion.actions.detect do |a|
      Object.const_get(a.type).ancestors.include?(
        Spree::Promotion::Actions::CreateLineItems
      )
    end

    if discount || created_line_items
      order.update_totals
      order.persist_totals
      set_success_code :coupon_code_applied
    elsif order.promotions.with_coupon_code(order.coupon_code)
      # if the promotion exists on an order, but wasn't found above,
      # we've already selected a better promotion
      set_error_code :coupon_code_better_exists
    else
      # if the promotion was created after the order
      set_error_code :coupon_code_not_found
    end
  end
end
