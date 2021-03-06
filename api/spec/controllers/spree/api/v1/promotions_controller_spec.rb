require 'spec_helper'

module Spree
  describe Api::V1::PromotionsController, type: :controller do
    render_views

    shared_examples 'a JSON response' do
      it 'should be ok' do
        expect(subject).to be_ok
      end

      it 'should return JSON' do
        payload = HashWithIndifferentAccess.new(JSON.parse(subject.body))
        expect(payload).to_not be_nil
        Spree::Api::ApiHelpers.promotion_attributes.each do |attribute|
          expect(payload.key?(attribute)).to be true
        end
      end
    end

    before do
      stub_authentication!
    end

    let!(:promotion) { create :multicode_promotion, :with_order_adjustment, code: '10off' }
    let!(:code) { create(:promotion_code, promotion: promotion) }

    describe 'GET #show' do
      subject { api_get :show, id: id }

      context 'when admin' do
        sign_in_as_admin!

        context 'when finding by id' do
          let(:id) { promotion.id }

          it_behaves_like 'a JSON response'
        end

        context 'when finding by code' do
          let(:id) { code.value }

          it_behaves_like 'a JSON response'
        end

        context 'when id does not exist' do
          let(:id) { 'argh' }

          it 'should be 404' do
            expect(subject.status).to eq(404)
          end
        end
      end

      context 'when non admin' do
        let(:id) { promotion.id }

        it 'should be unauthorized' do
          subject
          assert_unauthorized!
        end
      end
    end
  end
end
