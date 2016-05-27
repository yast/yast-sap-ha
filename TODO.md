- [ ] Clicking on 'x' window button goes back instead of aborting the Wizard. WTF?

This code gives error in ncurses but works in gui:

```ruby
    def refresh_view
      Wizard.DisableBackButton
      Wizard.SetNextButton(:install, "&Install")
      log.warn "--- #{self.class}.#{__callee__} : can_install=#{@config.can_install?.inspect} ---"
      if @config.can_install?
        Wizard.EnableNextButton
      else
        Wizard.DisableNextButton
      end
    end
```

and produces the following log

2016-05-20 20:01:35 <2> d50(7418) [Ruby] sap_ha_wizard/summary_page.rb:29 --- Yast::SetupSummaryPage.refresh_view : can_install=false ---
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 Neither `next nor `accept widgets exist
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 ------------- Backtrace begin -------------
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /usr/share/YaST2/modules/Wizard.rb:1252:in `DisableNextButton'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /root/yast-sap-ha/src/lib/sap_ha_wizard/summary_page.rb:33:in `refresh_view'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /root/yast-sap-ha/src/lib/sap_ha_wizard/summary_page.rb:23:in `set_contents'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /root/yast-sap-ha/src/lib/sap_ha_wizard/base_wizard_page.rb:45:in `run'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /root/yast-sap-ha/src/clients/sap_ha.rb:302:in `general_setup'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /root/yast-sap-ha/src/clients/sap_ha.rb:204:in `block in main'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /usr/lib64/ruby/vendor_ruby/2.1.0/yast/builtins.rb:542:in `call'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /usr/lib64/ruby/vendor_ruby/2.1.0/yast/builtins.rb:542:in `eval'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /usr/share/YaST2/modules/Sequencer.rb:263:in `WS_run'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /usr/share/YaST2/modules/Sequencer.rb:335:in `block in Run'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /usr/share/YaST2/modules/Sequencer.rb:327:in `loop'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /usr/share/YaST2/modules/Sequencer.rb:327:in `Run'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /root/yast-sap-ha/src/clients/sap_ha.rb:216:in `main'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /root/yast-sap-ha/src/clients/sap_ha.rb:352:in `<module:Yast>'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /root/yast-sap-ha/src/clients/sap_ha.rb:16:in `<top (required)>'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /usr/lib64/ruby/vendor_ruby/2.1.0/yast/wfm.rb:189:in `eval'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 /usr/lib64/ruby/vendor_ruby/2.1.0/yast/wfm.rb:189:in `run_client'
2016-05-20 20:01:35 <3> d50(7418) [Ruby] modules/Wizard.rb:1252 ------------- Backtrace end ---------------


moving `Wizard.SetNextButton(:install, "&Install")` after the enable/disable methods does not change anything