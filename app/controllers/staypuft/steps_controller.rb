module Staypuft
  class StepsController < ApplicationController
    include Wicked::Wizard
    steps :deployment_settings, :services_selection, :services_configuration

    before_filter :get_deployment

    def show
      case step
      when :deployment_settings
        @layouts = ordered_layouts
      when :services_configuration
        @service_hostgroup_map = @deployment.services_hostgroup_map
      end

      render_wizard
    end

    def update
      case step
      when :deployment_settings
        @layouts = ordered_layouts

        Deployment.transaction do
          @deployment.form_step = Deployment::STEP_SETTINGS unless @deployment.form_complete?
          @deployment.update_attributes(params[:staypuft_deployment])
          @deployment.update_hostgroup_list
          @deployment.set_custom_params
        end
      when :services_selection
        @deployment.form_step = Deployment::STEP_SELECTION unless @deployment.form_complete?
      when :services_configuration
        # Collect services across all deployment's roles
        @service_hostgroup_map = @deployment.services_hostgroup_map
        if params[:staypuft_deployment]
          @deployment.form_step = Deployment::STEP_CONFIGURATION unless @deployment.form_complete?
          param_data = params[:staypuft_deployment][:hostgroup_params]
          param_data.each do |hostgroup_id, hostgroup_params|
            hostgroup = Hostgroup.find(hostgroup_id)
            hostgroup_params[:puppetclass_params].each do |puppetclass_id, puppetclass_params|
              puppetclass = Puppetclass.find(puppetclass_id)
              puppetclass_params.each do |param_name, param_value|
                hostgroup.set_param_value_if_changed(puppetclass, param_name, param_value)
              end
            end
          end
        end
      end

      render_wizard @deployment
    end

    private
    def get_deployment
      @deployment      = Deployment.find(params[:deployment_id])
      @deployment.name = nil if @deployment.name.starts_with?(Deployment::NEW_NAME_PREFIX)
    end

    def redirect_to_finish_wizard(options = {})
      redirect_to deployment_path(@deployment), :notice => _("Deployment has been succesfully configured.")
    end

    def ordered_layouts
      Layout.order(:name).order("networking DESC").all
    end
  end
end
