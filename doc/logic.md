# Program logic

## Start in wizard mode

0. User starts the program
1. Read the parameters:
    These are simple reads, we don't need to do anything with the data we have obtained.
    - SAP Installation
        ??? What if we have more than one installation?
        If no installation was detected, go to final step and exit.
    - network interfaces
    - sshd settings
    - ntpd settings
    - check the required packages (if not installed, issue a warning and open the `sw_management`)
2. Open the wizard, show greeting.
    Here if we have more than one product, let the user select the product.
3. => Scenario selection (product-dependent).
    Here the user can select the scenario from the list. This selection may affect other steps.
4. => 




# Services
sbd.service
sshd
ntpd
