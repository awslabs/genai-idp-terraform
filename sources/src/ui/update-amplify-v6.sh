#!/bin/bash

# Update files with API, graphqlOperation imports
for file in src/components/discovery/DiscoveryPanel.jsx \
            src/components/document-viewers/DocumentViewers.jsx \
            src/components/sections-panel/SectionsPanel.jsx \
            src/components/step-function-flow/StepFunctionFlowViewer.jsx \
            src/components/upload-document/UploadDocumentPanel.jsx; do

  if [ -f "$file" ]; then
    echo "Updating $file..."

    # Replace import statement
    sed -i '' "s/import { API, graphqlOperation } from 'aws-amplify'/import { generateClient } from 'aws-amplify\/api'/g" "$file"

    # Add client declaration after imports
    sed -i '' "/^import.*from.*;$/a\\
const client = generateClient();\\
" "$file" | head -1

    # Replace API.graphql(graphqlOperation(...)) with client.graphql({ query: ..., variables: ... })
    sed -i '' 's/API\.graphql(graphqlOperation(\([^,]*\), \([^)]*\)))/client.graphql({ query: \1, variables: \2 })/g' "$file"
    sed -i '' 's/API\.graphql(graphqlOperation(\([^)]*\)))/client.graphql({ query: \1 })/g' "$file"
  fi
done

# Update files with API, Logger imports (without graphqlOperation)
for file in src/components/document-viewer/*.jsx \
            src/components/document-panel/*.jsx \
            src/components/document-kb-query-layout/*.jsx \
            src/components/document-agents-layout/*.jsx \
            src/components/chat-panel/*.jsx; do

  if [ -f "$file" ]; then
    echo "Updating $file..."

    # Replace import statement
    sed -i '' "s/import { API, Logger } from 'aws-amplify'/import { generateClient } from 'aws-amplify\/api';\nimport { ConsoleLogger } from 'aws-amplify\/utils'/g" "$file"

    # Replace API.graphql with client.graphql
    sed -i '' 's/API\.graphql/client.graphql/g' "$file"
  fi
done

echo "Done!"
