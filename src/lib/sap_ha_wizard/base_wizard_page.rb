require 'yast'
require 'sap_ha/helpers'

module Yast
  # Base Wizard page class
  class BaseWizardPage
    Yast.import 'UI'
    Yast.import 'Wizard'
    include Yast::Logger
    include Yast::I18n
    include Yast::UIShortcuts

    attr_accessor :model

    # Initialize the Wizard page
    def initialize(model)
      log.debug "--- called #{self.class}.#{__callee__} ---"
      @model = model
    end

    # Set the Wizard's contents, help and the back/next buttons
    def set_contents
      log.debug "--- called #{self.class}.#{__callee__} ---"
    end

    # Refresh the view, populating the values from the model
    def refresh_view
    end

    # Return true if the user can proceed to the next screen
    # Use this if additional verification of the data is needed
    def can_go_next
      true
    end

    # Handle custom user input
    # @param input [Symbol]
    def handle_user_input(input)
      log.debug "--- #{self.class}.#{__callee__} : UserInput returned input=#{input} ---"
    end

    # Set the contents and run the loop
    def run
      log.debug "--- #{self.class}.#{__callee__} ---"
      set_contents
      main_loop
    end

    protected

    # Run the main input processing loop
    # Ideally, this method should not be redefined (if we lived in a perfect world)
    def main_loop
      log.debug "--- #{self.class}.#{__callee__} ---"
      loop do
        input = Wizard.UserInput
        log.debug "--- #{self.class}.#{__callee__} ---"
        case input
        when :abort, :back
          return input
        when :next
          return :next if can_go_next
        else
          handle_user_input(input)
        end
      end
    end

    private

    # Base layout that wraps all the widgets
    def base_layout(contents)
      log.debug "--- #{self.class}.#{__callee__} ---"
      HBox(
        HSpacing(3),
        contents,
        HSpacing(3)
      )
    end

    # Base layout that wraps all the widgets
    def base_layout_with_label(label_text, contents)
      log.debug "--- #{self.class}.#{__callee__} ---"
      base_layout(
        VBox(
          HSpacing(80),
          VSpacing(1),
          Left(Label(label_text)),
          VSpacing(1),
          contents,
          VSpacing(Opt(:vstretch))
        )
      )
    end

    # A dynamic popup showing the message and the widgets.
    # Runs the validators method to check user input
    # @param message [String] a message to display
    # @param validators [Lambda] validation routine
    # @param widgets [Array] widgets to show
    def base_popup(message, validators, *widgets)
      log.debug "--- #{self.class}.#{__callee__} ---"
      UI.OpenDialog(
        VBox(
          Label(message),
          *widgets,
          Wizard.CancelOKButtonBox
        )
      )
      loop do
        ui = UI.UserInput
        case ui
        when :ok
          parameters = {}
          widgets.select { |w| [:InputField, :TextEntry].include? w.value }.each do |w|
            id = w.params.find do |parameter|
              parameter.respond_to?(:value) && parameter.value == :id
            end.params[0]
            parameters[id] = UI.QueryWidget(Id(id), :Value)
          end
          if validators
            ret = validators.call(parameters)
            next unless ret
          end
          UI.CloseDialog
          return parameters
        when :cancel
          UI.CloseDialog
          return nil
        end
      end
    end
  end
end
