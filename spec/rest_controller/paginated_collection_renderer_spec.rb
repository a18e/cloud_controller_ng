require 'spec_helper'

module VCAP::CloudController::RestController
  describe PaginatedCollectionRenderer do
    db = Sequel.sqlite(':memory:')

    db.create_table :cars do
      primary_key :id
      String :guid
      String :name
      Time :created_at
    end

    class Car < Sequel::Model(db)
      attr_accessor :id, :created_at
      export_attributes :name
    end

    class CarsController < ModelController
      define_attributes {}
    end

    subject(:paginated_collection_renderer) { PaginatedCollectionRenderer.new(eager_loader, serializer, renderer_opts) }
    let(:eager_loader) { SecureEagerLoader.new }
    let(:serializer) { PreloadedObjectSerializer.new }
    let(:renderer_opts) do
      {
        default_results_per_page: default_results_per_page,
        max_results_per_page: max_results_per_page,
        max_inline_relations_depth: max_inline_relations_depth,
      }
    end
    let(:default_results_per_page) { 100_000 }
    let(:max_results_per_page) { 100_000 }
    let(:max_inline_relations_depth) { 100_000 }

    describe '#render_json' do
      let(:opts) do
        {
            results_per_page: results_per_page,
            inline_relations_depth: inline_relations_depth
        }
      end
      let(:inline_relations_depth) { nil }
      let(:results_per_page) { nil }

      subject(:render_json_call) do
        paginated_collection_renderer.render_json(CarsController, Car.dataset, "/v2/cars", opts, {})
      end

      context 'when asked results_per_page is more than max results_per_page' do
        let(:max_results_per_page) { 10 }
        let(:results_per_page) { 11 }

        it 'raises ApiError error' do
          expect { render_json_call }.to raise_error(VCAP::Errors::ApiError, /results_per_page/)
        end
      end

      context 'when asked results_per_page equals to max results_per_page' do
        let(:max_results_per_page) { 10 }
        let(:results_per_page) { 10 }

        it 'renders json response' do
          expect(render_json_call).to be_instance_of(String)
        end
      end

      context 'when asked results_per_page is less than max results_per_page' do
        let(:max_results_per_page) { 10 }
        let(:results_per_page) { 9 }

        it 'renders json response' do
          expect(render_json_call).to be_instance_of(String)
        end
      end

      context 'when results_per_page were not specified' do
        before do
          Car.create(name: "car-1")
          Car.create(name: "car-2")
        end

        let(:default_results_per_page) { 1 }

        it 'renders limits number of results to default_results_per_page' do
          expect(JSON.parse(render_json_call)["resources"].size).to eq(1)
        end
      end

      context 'when asked inline_relations_depth is more than max inline_relations_depth' do
        let(:max_inline_relations_depth) { 10 }
        let(:inline_relations_depth) { 11 }

        it 'raises BadQueryParameter error' do
          expect {
            render_json_call
          }.to raise_error(VCAP::Errors::ApiError, /inline_relations_depth/)
        end
      end

      context 'when asked inline_relations_depth equals to max inline_relations_depth' do
        let(:max_inline_relations_depth) { 10 }
        let(:inline_relations_depth) { 10 }

        it 'renders json response' do
          expect(render_json_call).to be_instance_of(String)
        end
      end

      context 'when asked inline_relations_depth is less than max inline_relations_depth' do
        let(:max_inline_relations_depth) { 10 }
        let(:inline_relations_depth) { 9 }

        it 'renders json response' do
          expect(render_json_call).to be_instance_of(String)
        end
      end
    end
  end
end
