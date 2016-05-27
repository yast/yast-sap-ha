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
      log.warn "--- #{self.class}.#{__callee__} : Unexpected user input=#{input.inspect} ---"
    end

    # Set the contents of the Wizard's page and run the event loop
    def run
      log.debug "--- #{self.class}.#{__callee__} ---"
      set_contents
      refresh_view
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
        # TODO: return only :abort and :back from here. If the page needs anything else
        # it should redefine the main_loop
        when :abort, :back, :summary, :join_cluster
          return input
        when :next
          return :next if can_go_next
        else
          handle_user_input(input)
        end
      end
    end

    private

    # Obtain a property of a widget
    # @param widget_id [Symbol]
    # @param property [Symbol]
    def value(widget_id, property = :Value)
      UI.QueryWidget(Id(widget_id), property)
    end

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
      input_widgets = [:InputField, :TextEntry, :Password,
                       :SelectionBox, :MinWidth, :MinHeight, :MinSize]
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
          widgets.select { |w| input_widgets.include? w.value }.each do |w|
            # if the actual widget is wrapped within a size widget
            if w.value == :MinWidth || w.value == :MinHeight
              w = w.params[1]
            elsif w.value == :MinSize
              w = w.params[2]
            end
            # TODO: check once more, just to be sure :)
            # next unless input_widgets.include? w
            id = w.params.find do |parameter|
              parameter.respond_to?(:value) && parameter.value == :id
            end.params[0]
            parameters[id] = UI.QueryWidget(Id(id), :Value)
          end
          log.debug "--- #{self.class}.#{__callee__} popup parameters: #{parameters} ---"
          if validators && !@model.no_validators
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

    # Create a Wizard page with just a RichText widget on it
    # @param title [String]
    # @param contents [Yast::UI::Term]
    # @param help [String]
    # @param allow_back [Boolean]
    # @param allow_next [Boolean]
    def base_rich_text(title, contents, help, allow_back, allow_next)
      Wizard.SetContents(
        title,
        base_layout(
          RichText(contents)
        ),
        help,
        allow_back,
        allow_next
      )
    end

    # Create a true/false combo box
    # @param id_ [Symbol] widget's ID
    # @param label [String] combo's label
    # @param true_ [Boolean] 'true' option is selected
    def base_true_false_combo(id_, label='', true_=true)
      ComboBox(Id(id_), label,
        [
          Item(Id(:true), 'true', true_),
          Item(Id(:false), 'false', !true_),
        ]
      )
    end

    # Prompt the user for the password
    # Do not use base_popup because it logs the input!
    # @param message [String] additional prompt message
    def password_prompt(message)
      UI.OpenDialog(
        VBox(
          Label(message),
          Password(Id(:password), 'Password:', ''),
          Wizard.CancelOKButtonBox
        )
      )
      ui = UI.UserInput
      case ui
      when :cancel
        UI.CloseDialog
        return nil
      when :ok
        UI.CloseDialog
        pass = value(:password)
        return nil if pass.empty?
        pass
      end
    end

    def show_dialog_errors(error_list)

      html_str = "<ul>\n"
      html_str << error_list.map { |e| "<li>#{e}</li>" }.join("\n")
      html_str << "</ul>"
      # Popup.LongError(error_list.join("\n"))
      # Popup.LongError(html_str)
      Popup.LongText("Invalid input", RichText(html_str), 60, 17)
    end
  end
end
