
#!/bin/bash

./fld-test-prepare.sh
echo -e "START testing....\n"
echo -e "\nService registration.."
expect -f ./TestCreateService.exp
