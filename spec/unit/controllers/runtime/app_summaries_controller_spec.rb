require 'spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe AppSummariesController do
    before do
      @num_services  = 2
      @free_mem_size = 128

      @shared_domain = SharedDomain.make
      @shared_domain.save

      @space = Space.make
      @environment_json = { 'HELLO' => 'WORLD' }
      @route1 = Route.make(space: @space)
      @route2 = Route.make(space: @space)
      @services = []

      @process = ProcessModelFactory.make(
        space:      @space,
        production: false,
        instances:  1,
        memory:     @free_mem_size,
        state:      'STARTED',
        environment_json: @environment_json
      )

      @num_services.times do
        instance                            = ManagedServiceInstance.make(space: @space)
        instance.service_instance_operation = ServiceInstanceOperation.make(
          type:        'create',
          state:       'in progress',
          description: 'description goes here'
        )
        @services << instance
        ServiceBinding.make(app: @process.app, service_instance: instance)
      end

      RouteMappingModel.make(app: @process.app, route: @route1, process_type: @process.type)
      RouteMappingModel.make(app: @process.app, route: @route2, process_type: @process.type)

      set_current_user_as_admin
    end

    describe 'GET /v2/apps/:id/summary' do
      let(:instances_reporters) { double(:instances_reporters) }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:instances_reporters).and_return(instances_reporters)
      end

      context 'when the instances reporter reports instances' do
        before do
          allow(instances_reporters).to receive(:number_of_starting_and_running_instances_for_process).and_return(@process.instances)

          get "/v2/apps/#{@process.app.guid}/summary"
        end

        it 'should contain the basic app attributes' do
          expect(last_response.status).to eq(200)
          expect(decoded_response['guid']).to eq(@process.app.guid)
          expect(decoded_response['environment_json']).to eq({ 'HELLO' => 'WORLD' })

          parse(MultiJson.dump(@process.to_hash)).each do |k, v|
            expect(v).to eql(decoded_response[k.to_s]), "value of field #{k} expected to eql #{v}"
          end
        end

        it 'should return the app routes' do
          expect(decoded_response['routes']).to eq([{
            'guid'   => @route1.guid,
            'host'   => @route1.host,
            'port'   => @route1.port,
            'path'   => @route1.path,
            'domain' => {
              'guid' => @route1.domain.guid,
              'name' => @route1.domain.name
            }
          }, {
            'guid'   => @route2.guid,
            'host'   => @route2.host,
            'port'   => @route2.port,
            'path'   => @route2.path,
            'domain' => {
              'guid' => @route2.domain.guid,
              'name' => @route2.domain.name }
          }])
        end

        it 'should contain the running instances' do
          expect(decoded_response['running_instances']).to eq(@process.instances)
        end

        it 'should contain list of both private domains and shared domains' do
          domains = @process.space.organization.private_domains
          expect(domains.count > 0).to eq(true)

          private_domains = domains.collect do |domain|
            { 'guid'                     => domain.guid,
              'name'                     => domain.name,
              'owning_organization_guid' =>
                domain.owning_organization.guid
            }
          end

          shared_domains = SharedDomain.all.collect do |domain|
            { 'guid'              => domain.guid,
              'name'              => domain.name,
              'internal' => domain.internal,
              'router_group_guid' => domain.router_group_guid,
              'router_group_type' => domain.router_group_type,
            }
          end

          expect(decoded_response['available_domains']).to match_array(private_domains + shared_domains)
        end

        it 'should return the correct info for services' do
          expect(decoded_response['services'].size).to eq(@num_services)
          svc_resp = decoded_response['services'][0]
          svc      = @services.find { |s| s.guid == svc_resp['guid'] }

          expect(svc_resp).to include({
            'guid'            => svc.guid,
            'name'            => svc.name,
            'bound_app_count' => 1,
            'dashboard_url'   => svc.dashboard_url,
            'service_plan'    => {
              'guid'    => svc.service_plan.guid,
              'name'    => svc.service_plan.name,
              'maintenance_info' => {},
              'service' => {
                'guid'     => svc.service_plan.service.guid,
                'label'    => svc.service_plan.service.label,
                'provider' => svc.service_plan.service.provider,
                'version'  => svc.service_plan.service.version,
              }
            }
          })

          expect(svc_resp['last_operation']).to include({
            'type'        => 'create',
            'state'       => 'in progress',
            'description' => 'description goes here',
          })

          expect(svc_resp['last_operation']['updated_at']).to be
        end
      end
    end
  end
end
