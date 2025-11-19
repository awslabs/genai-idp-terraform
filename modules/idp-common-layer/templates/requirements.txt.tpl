# IDP Common Library Dependencies
# This file contains only the dependencies for the idp_common package
# The idp_common package itself will be installed separately

# Core dependencies
boto3>=1.37.29

# Additional dependencies based on extras
%{ for extra in extras }
%{ if extra == "image" || extra == "all" }
Pillow>=11.1.0
%{ endif }
%{ if extra == "ocr" || extra == "all" }
PyMuPDF>=1.25.5
amazon-textract-textractor[pandas]>=1.9.2
%{ endif }
%{ if extra == "evaluation" || extra == "all" }
munkres>=1.1.4
numpy>=1.24.0
%{ endif }
%{ if extra == "appsync" || extra == "all" }
requests>=2.32.3
%{ endif }
%{ endfor }
