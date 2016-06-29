# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE Linux GmbH, Nuernberg, Germany.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE Linux GmbH.
#
# ------------------------------------------------------------------------------
#
# Summary: SUSE High Availability Setup for SAP Products
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require_relative '../../../test_helper'
require 'sap_ha/helpers'
require 'sap_ha/exceptions'
require 'sap_ha/configuration'

describe SapHA::HelpersClass do

  describe '#instance' do
    it 'instantiates the Singleton' do
      result = SapHA::HelpersClass.instance
      expect(result).not_to be_nil
    end
  end

  describe '#render_template' do
    it 'renders the GUI template for two-ring cluster' do
      @config = prepare_hana_config
      expect(@config.can_install?).to eq true
      begin
        result = SapHA::Helpers.render_template('tmpl_config_overview_gui.erb', binding)
      rescue SapHA::Exceptions::TemplateRenderException => e
        raise SapHA::Exceptions::TemplateRenderException, e.renderer_message
      end
      expect(result).not_to be_nil
    end

    it 'renders the GUI template for single-ring cluster' do
      @config = prepare_hana_config(nil, number_of_rings: 1)
      expect(@config.can_install?).to eq true
      begin
        result = SapHA::Helpers.render_template('tmpl_config_overview_gui.erb', binding)
      rescue SapHA::Exceptions::TemplateRenderException => e
        raise SapHA::Exceptions::TemplateRenderException, e.renderer_message
      end
      expect(result).not_to be_nil
    end

    it 'renders the ncurses template for two-ring cluster' do
      @config = prepare_hana_config
      expect(@config.can_install?).to eq true
      begin
        result = SapHA::Helpers.render_template('tmpl_config_overview_con.erb', binding)
      rescue SapHA::Exceptions::TemplateRenderException => e
        raise SapHA::Exceptions::TemplateRenderException, e.renderer_message
      end
      expect(result).not_to be_nil
    end

    it 'renders the ncurses template for single-ring cluster' do
      @config = prepare_hana_config(nil, number_of_rings: 1)
      expect(@config.can_install?).to eq true
      begin
        result = SapHA::Helpers.render_template('tmpl_config_overview_con.erb', binding)
      rescue SapHA::Exceptions::TemplateRenderException => e
        raise SapHA::Exceptions::TemplateRenderException, e.renderer_message
      end
      expect(result).not_to be_nil
    end
  end

  describe '#load_help' do
    it 'loads the required help file' do
      %w(cluster fencing hana join_cluster ntp product_not_found setup_summary watchdog).each do |hn|
        result = SapHA::Helpers.load_help(hn)
        expect(result).not_to be_nil
      end
      expect{ SapHA::Helpers.load_help('__unknown__') }.to raise_error(RuntimeError)
    end
  end

  describe '#data_file_path' do
    it 'returns a path to the data file' do
      result = SapHA::Helpers.data_file_path('scenarios.yaml')
      expect(result).not_to be_nil
    end
  end

  describe '#var_file_path' do
    it 'returns a path to the temporary file' do
      result = SapHA::Helpers.var_file_path('temporary')
      expect(result).not_to be_nil
    end
  end

  # # TODO: auto-generated
  # describe '#write_var_file' do
  #   it 'works' do
  #     helpers_class = SapHA::HelpersClass.new
  #     basename = double('basename')
  #     data = double('data')
  #     result = helpers_class.write_var_file(basename, data)
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#write_file' do
  #   it 'works' do
  #     helpers_class = SapHA::HelpersClass.new
  #     path = double('path')
  #     data = double('data')
  #     result = helpers_class.write_file(path, data)
  #     expect(result).not_to be_nil
  #   end
  # end

  # # TODO: auto-generated
  # describe '#open_url' do
  #   it 'works' do
  #     helpers_class = SapHA::HelpersClass.new
  #     url = double('url')
  #     result = helpers_class.open_url(url)
  #     expect(result).not_to be_nil
  #   end
  # end

end
