require 'yast'
require 'sap_ha/helpers'

module Yast
  # Installation Summary page
  class SetupSummaryPage < BaseWizardPage
    attr_accessor :model

    def initialize(model)
      @config = model
    end

    def set_contents
      super
      base_rich_text(
        "High-Availability Setup Summary",
        UI.TextMode ? SAPHAHelpers.instance.render_template('setup_summary_ncurses.erb', binding) :
        SAPHAHelpers.instance.render_template('setup_summary_gui.erb', binding),
        SAPHAHelpers.instance.load_html_help('setup_summary_help.html'),
        true,
        true
        )
      refresh_view
    end

    def refresh_view
      Wizard.DisableBackButton
      log.warn "--- #{self.class}.#{__callee__} : can_install=#{@config.can_install?.inspect} ---"
      if @config.can_install?
        Wizard.EnableNextButton
      else
        Wizard.DisableNextButton
      end
      Wizard.SetNextButton(:install, "&Install")
    end

    def can_go_next
      false
    end

    protected

    def main_loop
      log.debug "--- #{self.class}.#{__callee__} ---"
      input = Wizard.UserInput
      log.debug "--- #{self.class}.#{__callee__}: input is #{input.inspect} ---"
      Wizard.SetNextButton(:summary, "&Summary") unless input == :next
      return input.to_sym
    end
  end
end
