class ProxyDepositRequest < ActiveRecord::Base
  include Blacklight::SearchHelper
  include ActionView::Helpers::UrlHelper

  belongs_to :receiving_user, class_name: 'User'
  belongs_to :sending_user, class_name: 'User'

  # attribute generic_work_id exists as result of renaming in db migrations.
  # See upgrade600_generator.rb and upgrade700_generator.rb

  validates :sending_user, :generic_work_id, presence: true
  validate :transfer_to_should_be_a_valid_username
  validate :sending_user_should_not_be_receiving_user
  validate :should_not_be_already_part_of_a_transfer

  after_save :send_request_transfer_message

  attr_reader :transfer_to

  def transfer_to=(key)
    @transfer_to = key
    self.receiving_user = User.find_by_user_key(key)
  end

  def transfer_to_should_be_a_valid_username
    errors.add(:transfer_to, "must be an existing user") unless receiving_user
  end

  def sending_user_should_not_be_receiving_user
    errors.add(:sending_user, 'must specify another user to receive the work') if receiving_user && receiving_user.user_key == sending_user.user_key
  end

  def should_not_be_already_part_of_a_transfer
    transfers = ProxyDepositRequest.where(generic_work_id: generic_work_id, status: 'pending')
    errors.add(:open_transfer, 'must close open transfer on the work before creating a new one') unless transfers.blank? || (transfers.count == 1 && transfers[0].id == id)
  end

  def send_request_transfer_message
    if updated_at == created_at
      message = "#{link_to(sending_user.name, Sufia::Engine.routes.url_helpers.profile_path(sending_user.user_key))} wants to transfer a work to you. Review all <a href='#{Sufia::Engine.routes.url_helpers.transfers_path}'>transfer requests</a>"
      User.batchuser.send_message(receiving_user, message, "Ownership Change Request")
    else
      message = "Your transfer request was #{status}."
      message += " Comments: #{receiver_comment}" unless receiver_comment.blank?
      User.batchuser.send_message(sending_user, message, "Ownership Change #{status}")
    end
  end

  def pending?
    status == 'pending'
  end

  def accepted?
    status == 'accepted'
  end

  # @param [Boolean] reset (false) should the access controls be reset. This means revoking edit access from the depositor
  def transfer!(reset = false)
    ContentDepositorChangeEventJob.perform_later(generic_work_id, receiving_user.user_key, reset)
    self.status = 'accepted'
    self.fulfillment_date = Time.now
    save!
  end

  def reject!(comment = nil)
    self.receiver_comment = comment if comment
    self.status = 'rejected'
    self.fulfillment_date = Time.now
    save!
  end

  def cancel!
    self.status = 'canceled'
    self.fulfillment_date = Time.now
    save!
  end

  def deleted_work?
    !GenericWork.exists?(generic_work_id)
  end

  def title
    return 'work not found' if deleted_work?
    query = ActiveFedora::SolrQueryBuilder.construct_query_for_ids([generic_work_id])
    solr_response = ActiveFedora::SolrService.query(query, raw: true)
    SolrDocument.new(solr_response['response']['docs'].first, solr_response).title
  end
end
