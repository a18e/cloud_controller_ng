require 'actions/space_delete'

module VCAP::CloudController
  class OrganizationDelete
    def initialize(org_roles_deleter, space_deleter)
      @org_roles_deleter = org_roles_deleter
      @space_deleter = space_deleter
    end

    def delete(org_dataset)
      org_dataset.each do |org|
        errs = @space_deleter.delete(org.spaces_dataset)
        unless errs.empty?
          error_message = errs.map(&:message).join("\n\n")
          return [CloudController::Errors::ApiError.new_from_details('OrganizationDeletionFailed', org.name, error_message)]
        end

        errs = @org_roles_deleter.delete(org)
        unless errs.empty?
          error_message = errs.map(&:message).join("\n\n")
          return [CloudController::Errors::ApiError.new_from_details('OrganizationDeletionFailed', org.name, error_message)]
        end

        Organization.db.transaction do
          delete_labels(org)
          org.destroy
        end
      end
    end

    def timeout_error(dataset)
      org_name = dataset.first.name
      CloudController::Errors::ApiError.new_from_details('OrganizationDeleteTimeout', org_name)
    end

    private

    def delete_labels(org_model)
      LabelDelete.delete(org_model.labels)
    end
  end
end
