module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestPresenters
        class ProcessPropertiesPresenter
          def to_hash(app:, **_)
            processes = app.processes.sort_by(&:type).map { |process| process_hash(process) }
            { processes: processes.presence }
          end

          def process_hash(process)
            {
              'type' => process.type,
              'instances' => process.instances,
              'memory' => add_units(process.memory),
              'disk_quota' => add_units(process.disk_quota),
              'log-rate-limit-per-second' => add_units_log_rate_limit(process.log_rate_limit),
              'command' => process.command,
              'health-check-type' => process.health_check_type,
              'health-check-http-endpoint' => process.health_check_http_endpoint,
              'timeout' => process.health_check_timeout,
            }.compact
          end

          def add_units(val)
            "#{val}M"
          end

          def add_units_log_rate_limit(val)
            return -1 if val == -1

            byte_converter.human_readable_byte_value(val)
          end

          def byte_converter
            ByteConverter.new
          end
        end
      end
    end
  end
end
