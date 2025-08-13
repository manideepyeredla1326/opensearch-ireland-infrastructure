pipeline {
    agent any
    
    parameters {
        choice(
            name: 'OPERATION',
            choices: ['validate', 'plan', 'apply', 'import', 'backup-state'],
            description: 'Operation to perform'
        )
        string(
            name: 'AWS_REGION',
            defaultValue: 'eu-west-1',
            description: 'AWS region for the cluster'
        )
        string(
            name: 'DOMAIN_NAME',
            defaultValue: 'imiconnect-uk-prod',
            description: 'Name of the OpenSearch domain'
        )
        string(
            name: 'AWS_PROFILE',
            defaultValue: 'default',
            description: 'AWS profile name to use for credentials'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Auto approve terraform apply'
        )
    }
    
    environment {
        AWS_DEFAULT_REGION = "${params.AWS_REGION}"
        TF_VAR_file = "regions/${params.AWS_REGION}/${params.DOMAIN_NAME}.tfvars"
        STATE_REPO_PATH = "../opensearch-terraform-state"
        GPG_RECIPIENT = 'myeredla@cisco.com'
        PATH = "${env.WORKSPACE}:${env.PATH}"
    }
    
    stages {
        stage('Debug Workspace') {
            steps {
                sh '''
                    echo "=== WORKSPACE DEBUG INFO ==="
                    echo "Current directory: $(pwd)"
                    echo "Workspace: ${WORKSPACE}"
                    echo "Directory contents:"
                    ls -la
                    echo ""
                    echo "Looking for terraform files:"
                    find . -name "*.tf" -type f || echo "No .tf files found"
                    echo ""
                    echo "Looking for regions directory:"
                    find . -name "regions" -type d || echo "No regions directory found"
                    echo ""
                    echo "Environment variables:"
                    echo "TF_VAR_file: ${TF_VAR_file}"
                    echo "AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION}"
                    echo "STATE_REPO_PATH: ${STATE_REPO_PATH}"
                    echo "=========================="
                '''
            }
        }
        
        stage('Checkout') {
            steps {
                checkout scm
                sh '''
                    echo "Setting up state repository..."
                    if [ ! -d "$STATE_REPO_PATH" ]; then
                        echo "Cloning state repository..."
                        git clone https://github.com/manideepyeredla1326/opensearch-ireland-infrastructure.git $STATE_REPO_PATH
                    else
                        echo "Updating existing state repository..."
                        cd $STATE_REPO_PATH && git pull origin main
                    fi
                '''
            }
        }
        
        stage('Setup Tools') {
            steps {
                sh '''
                    echo "Setting up Terraform..."
                    if ! command -v terraform &> /dev/null; then
                        echo "Terraform not found, downloading..."
                        rm -rf terraform_1.6.0_darwin_amd64.zip terraform
                        
                        # Use curl if wget is not available
                        if command -v wget &> /dev/null; then
                            wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_darwin_amd64.zip
                        else
                            curl -LO https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_darwin_amd64.zip
                        fi
                        
                        unzip -o terraform_1.6.0_darwin_amd64.zip
                        chmod +x terraform
                        
                        # Add to PATH
                        export PATH=$PWD:$PATH
                        echo "Terraform downloaded and added to PATH"
                    else
                        echo "Terraform already available"
                    fi
                    
                    # Verify terraform installation
                    terraform version
                '''
            }
        }
        
        stage('Import Existing Cluster') {
            when {
                expression { params.OPERATION == 'import' }
            }
            steps {
                sh '''
                    echo "Importing existing cluster..."
                    if [ -f "scripts/import-existing-cluster.sh" ]; then
                        chmod +x scripts/import-existing-cluster.sh
                        ./scripts/import-existing-cluster.sh "${params.DOMAIN_NAME}" "${params.AWS_REGION}" "${TF_VAR_file}"
                    else
                        echo "ERROR: import-existing-cluster.sh script not found"
                        exit 1
                    fi
                '''
            }
        }
        
        stage('Validate tfvars File') {
            when {
                expression { params.OPERATION in ['validate', 'plan', 'apply'] }
            }
            steps {
                sh '''
                    echo "Validating tfvars file..."
                    if [ ! -f "${TF_VAR_file}" ]; then
                        echo "ERROR: tfvars file not found: ${TF_VAR_file}"
                        echo "Available files in regions directory:"
                        find regions -name "*.tfvars" 2>/dev/null || echo "No tfvars files found"
                        exit 1
                    else
                        echo "tfvars file found: ${TF_VAR_file}"
                        echo "Contents:"
                        cat "${TF_VAR_file}"
                    fi
                '''
            }
        }
        
        stage('Initialize') {
            when {
                expression { params.OPERATION in ['validate', 'plan', 'apply'] }
            }
            steps {
                sh '''
                    echo "Initializing Terraform..."
                    
                    # Set up PATH to include terraform
                    export PATH=$PWD:$PATH
                    
                    # Initialize terraform in current directory (not in terraform subdirectory)
                    terraform init -input=false
                    
                    echo "Terraform initialization completed"
                '''
            }
        }
        
        stage('Validate') {
            when {
                expression { params.OPERATION == 'validate' }
            }
            steps {
                sh '''
                    echo "Running validation..."
                    
                    # Set up PATH to include terraform
                    export PATH=$PWD:$PATH
                    
                    # Run terraform validate
                    terraform validate
                    
                    # Run custom validation script if it exists
                    if [ -f "scripts/validate-deployment.sh" ]; then
                        chmod +x scripts/validate-deployment.sh
                        ./scripts/validate-deployment.sh
                    else
                        echo "Note: validate-deployment.sh script not found, skipping custom validation"
                    fi
                '''
            }
        }
        
        stage('Plan') {
            when {
                expression { params.OPERATION in ['validate', 'plan', 'apply'] }
            }
            steps {
                sh '''
                    echo "Running Terraform plan..."
                    
                    # Set up PATH to include terraform
                    export PATH=$PWD:$PATH
                    
                    # Run terraform plan
                    terraform plan \
                        -var-file="${TF_VAR_file}" \
                        -out=tfplan \
                        -input=false
                    
                    echo "Terraform plan completed"
                '''
            }
        }
        
        stage('Apply') {
            when {
                expression { params.OPERATION == 'apply' }
            }
            steps {
                script {
                    def userInput = true
                    if (!params.AUTO_APPROVE) {
                        userInput = input(
                            id: 'Proceed',
                            message: 'Apply changes to OpenSearch cluster?',
                            parameters: [
                                [$class: 'BooleanParameterDefinition',
                                 defaultValue: false,
                                 description: 'Proceed with apply',
                                 name: 'Apply']
                            ]
                        )
                    }
                    
                    if (userInput) {
                        sh '''
                            echo "Applying Terraform changes..."
                            
                            # Set up PATH to include terraform
                            export PATH=$PWD:$PATH
                            
                            # Apply terraform changes
                            terraform apply -input=false tfplan
                            
                            echo "Terraform apply completed"
                        '''
                        
                        sh '''
                            echo "Backing up state to GitHub..."
                            if [ -f "scripts/backup-state-to-github.sh" ]; then
                                chmod +x scripts/backup-state-to-github.sh
                                ./scripts/backup-state-to-github.sh
                            else
                                echo "Warning: backup-state-to-github.sh script not found"
                            fi
                        '''
                    } else {
                        echo "Apply operation cancelled by user"
                    }
                }
            }
        }
        
        stage('Backup State') {
            when {
                expression { params.OPERATION == 'backup-state' }
            }
            steps {
                sh '''
                    echo "Backing up Terraform state..."
                    if [ -f "scripts/backup-state-to-github.sh" ]; then
                        chmod +x scripts/backup-state-to-github.sh
                        ./scripts/backup-state-to-github.sh
                    else
                        echo "ERROR: backup-state-to-github.sh script not found"
                        exit 1
                    fi
                '''
            }
        }
    }
    
    post {
        always {
            script {
                // Archive artifacts with better error handling
                try {
                    archiveArtifacts artifacts: 'backup-*.json', allowEmptyArchive: true
                } catch (Exception e) {
                    echo "Warning: Could not archive backup files: ${e.getMessage()}"
                }
                
                try {
                    archiveArtifacts artifacts: 'tfplan', allowEmptyArchive: true
                } catch (Exception e) {
                    echo "Warning: Could not archive tfplan: ${e.getMessage()}"
                }
                
                try {
                    archiveArtifacts artifacts: 'terraform.tfstate*', allowEmptyArchive: true
                } catch (Exception e) {
                    echo "Warning: Could not archive terraform state files: ${e.getMessage()}"
                }
            }
        }
        
        success {
            script {
                if (params.OPERATION == 'import') {
                    echo "✅ OpenSearch cluster successfully imported into Terraform management"
                } else if (params.OPERATION == 'apply') {
                    echo "✅ OpenSearch cluster changes applied successfully"
                } else if (params.OPERATION == 'plan') {
                    echo "✅ Terraform plan completed successfully"
                } else if (params.OPERATION == 'validate') {
                    echo "✅ Terraform validation completed successfully"
                } else if (params.OPERATION == 'backup-state') {
                    echo "✅ Terraform state backup completed successfully"
                }
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed during ${params.OPERATION} operation"
                echo "Check the logs above for detailed error information"
                
                // Display some debugging information
                sh '''
                    echo "=== FAILURE DEBUG INFO ==="
                    echo "Current directory: $(pwd)"
                    echo "Directory contents:"
                    ls -la || echo "Could not list directory"
                    echo ""
                    echo "Terraform files:"
                    find . -name "*.tf" -type f || echo "No .tf files found"
                    echo ""
                    echo "Terraform state files:"
                    find . -name "*.tfstate*" -type f || echo "No state files found"
                    echo "=========================="
                '''
            }
        }
        
        cleanup {
            // Clean up temporary files
            sh '''
                echo "Cleaning up temporary files..."
                rm -f terraform_1.6.0_darwin_amd64.zip
                # Keep terraform binary for potential reuse
                # rm -f terraform
            '''
        }
    }
}