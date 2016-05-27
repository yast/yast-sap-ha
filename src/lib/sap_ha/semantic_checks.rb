require 'sap_ha/exceptions'
require 'yast'

Yast.import 'IP'
Yast.import 'Hostname'

module Yast
  class SemanticChecks
    include Singleton

    def initialize
      @transaction = false
      @errors = []
    end

    def transaction_begin
      @errors = []
      @transaction = true
    end

    def transaction_end
      @transaction = false
      err_copy = @errors.dup
      @errors = []
      err_copy
    end

    def ipv4(ip, field_name = '')
      unless IP.Check4(ip)
        return error_string(field_name, IP.Valid4) unless @transaction
        @errors << error_string(field_name, IP.Valid4, ip)
      end
    end

    def hostname(name, field_name = '')
      unless Hostname.Check(name)
        return error_string(field_name, IP.Valid4) unless @transaction
        @errors << error_string(field_name, Hostname.ValidHost, name)
      end
    end

    def equal(rvalue, lvalue, message, inverse = false)
      eq = rvalue == lvalue
      return nil if eq ^ inverse
      return message unless @transaction
      @errors << message
    end

    def unique(message, inverse = false, *args)
      uniq = (args == (args & args))
      return nil if uniq ^ inverse
      return message unless @transaction
      @errors << message
    end

    def error_string(field_name, explanation, value = nil)
      field_name = field_name.strip
      explanation = explanation.strip
      explanation = explanation[0..-2] if explanation.end_with? '.'
      if field_name.empty?
        "Invalid input: #{explanation}"
      elsif value.nil?
        "Invalid entry for #{field_name}: #{explanation}."
      else
        "Invalid entry for #{field_name} [#{value}]: #{explanation}."
      end
    end
  end
end
