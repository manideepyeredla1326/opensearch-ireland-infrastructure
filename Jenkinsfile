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
            defaultValue: 'us-east-1',
            description: 'AWS region for the cluster'
        )
        string(
            name: 'DOMAIN_NAME',
            defaultValue: 'connect-qa-new',
            description: 'Name of the OpenSearch domain'
        )
        string(
            name: 'AWS_PROFILE',
            defaultValue: 'imiconnect-qa',
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
        AWS_PROFILE = "${params.AWS_PROFILE}"
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
                    echo ""
                    echo "Pipeline Parameters:"
                    echo "  OPERATION: ''' + params.OPERATION + '''"
                    echo "  DOMAIN_NAME: ''' + params.DOMAIN_NAME + '''"
                    echo "  AWS_REGION: ''' + params.AWS_REGION + '''"
                    echo "  AWS_PROFILE: ''' + params.AWS_PROFILE + '''"
                    echo "  AUTO_APPROVE: ''' + params.AUTO_APPROVE + '''"
                    echo ""
                    echo "Expected tfvars file: regions/''' + params.AWS_REGION + '''/''' + params.DOMAIN_NAME + '''.tfvars"
                    echo ""
                    echo "Environment variables:"
                    echo "AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION}"
                    echo "AWS_PROFILE: ${AWS_PROFILE}"
                    echo "STATE_REPO_PATH: ${STATE_REPO_PATH}"
                    echo "PATH: ${PATH}"
                    echo "=========================="
                '''
            }
        }
        
        stage('Setup Tools') {
            steps {
                sh '''
                    echo "Setting up Terraform..."
                    if ! command -v terraform &> /dev/null; then
                        echo "Downloading Terraform..."
                        curl -LO https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_darwin_amd64.zip
                        unzip -o terraform_1.6.0_darwin_amd64.zip
                        chmod +x terraform
                    fi
                    
                    echo "Verifying tools..."
                    export PATH=$PWD:$PATH
                    terraform version
                    
                    # Verify AWS CLI and profile
                    if command -v aws &> /dev/null; then
                        echo "✅ AWS CLI found"
                        aws --version
                    else
                        echo "❌ AWS CLI not found"
                        exit 1
                    fi
                    
                    echo "✅ All tools ready"
                '''
            }
        }
        
        stage('Verify AWS Access') {
            steps {
                sh '''
                    echo "Verifying AWS access with profile: $AWS_PROFILE"
                    
                    # Test AWS connectivity with specific profile
                    if aws sts get-caller-identity --profile "$AWS_PROFILE" --region "$AWS_DEFAULT_REGION"; then
                        echo "✅ AWS access verified with profile $AWS_PROFILE"
                    else
                        echo "❌ AWS access failed with profile $AWS_PROFILE"
                        echo ""
                        echo "Available AWS profiles:"
                        aws configure list-profiles || echo "No profiles found"
                        echo ""
                        echo "Please ensure:"
                        echo "1. Profile '$AWS_PROFILE' exists"
                        echo "2. You're authenticated (may need to refresh ADFS token)"
                        exit 1
                    fi
                    
                    # Test OpenSearch access
                    echo "Testing OpenSearch access..."
                    aws opensearch list-domain-names --region "$AWS_DEFAULT_REGION" --profile "$AWS_PROFILE" || {
                        echo "⚠️ Cannot list OpenSearch domains (may be normal if no permissions)"
                    }
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
        
        stage('Validate tfvars File') {
            when {
                expression { params.OPERATION in ['validate', 'plan', 'apply'] }
            }
            environment {
                DOMAIN_NAME = "${params.DOMAIN_NAME}"
                AWS_REGION = "${params.AWS_REGION}"
                TF_VAR_FILE = "regions/${params.AWS_REGION}/${params.DOMAIN_NAME}.tfvars"
            }
            steps {
                sh '''
                    echo "Validating tfvars file..."
                    echo "Expected file: $TF_VAR_FILE"
                    
                    if [ ! -f "$TF_VAR_FILE" ]; then
                        echo "❌ ERROR: tfvars file not found: $TF_VAR_FILE"
                        echo ""
                        echo "Available files in regions directory:"
                        find regions -name "*.tfvars" 2>/dev/null || echo "No tfvars files found"
                        echo ""
                        echo "Directory structure:"
                        find regions -type d 2>/dev/null || echo "No regions directory found"
                        exit 1
                    else
                        echo "✅ tfvars file found: $TF_VAR_FILE"
                        echo ""
                        echo "File contents:"
                        echo "=============="
                        cat "$TF_VAR_FILE"
                        echo "=============="
                    fi
                '''
            }
        }
        
        stage('Import Existing Cluster') {
            when {
                expression { params.OPERATION == 'import' }
            }
            environment {
                DOMAIN_NAME = "${params.DOMAIN_NAME}"
                AWS_REGION = "${params.AWS_REGION}"
                TF_VAR_FILE = "regions/${params.AWS_REGION}/${params.DOMAIN_NAME}.tfvars"
                AWS_PROFILE = "${params.AWS_PROFILE}"
            }
            steps {
                sh '''
                    echo "Importing OpenSearch cluster..."
                    echo "Domain: $DOMAIN_NAME"
                    echo "Region: $AWS_REGION"
                    echo "TF Var File: $TF_VAR_FILE"
                    echo "AWS Profile: $AWS_PROFILE"
                    
                    # Set up PATH for terraform
                    export PATH=$PWD:$PATH
                    
                    # Verify tools are available
                    terraform version
                    aws --version
                    
                    # Test AWS access for this specific domain
                    echo "Checking if domain exists..."
                    if aws opensearch describe-domain --domain-name "$DOMAIN_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE"; then
                        echo "✅ Domain $DOMAIN_NAME found in region $AWS_REGION"
                    else
                        echo "❌ Cannot access domain $DOMAIN_NAME in region $AWS_REGION"
                        echo "Please check domain name and your AWS permissions"
                        exit 1
                    fi
                    
                    # Check tfvars file
                    if [ ! -f "$TF_VAR_FILE" ]; then
                        echo "❌ TF var file not found: $TF_VAR_FILE"
                        echo "Please create this file first"
                        exit 1
                    fi
                    
                    # Run import script
                    if [ -f "scripts/import-existing-cluster.sh" ]; then
                        chmod +x scripts/import-existing-cluster.sh
                        ./scripts/import-existing-cluster.sh "$DOMAIN_NAME" "$AWS_REGION" "$TF_VAR_FILE"
                    else
                        echo "❌ Import script not found: scripts/import-existing-cluster.sh"
                        exit 1
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
                    export PATH=$PWD:$PATH
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
                    export PATH=$PWD:$PATH
                    terraform validate
                    
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
            environment {
                DOMAIN_NAME = "${params.DOMAIN_NAME}"
                AWS_REGION = "${params.AWS_REGION}"
                TF_VAR_FILE = "regions/${params.AWS_REGION}/${params.DOMAIN_NAME}.tfvars"
            }
            steps {
                sh '''
                    echo "Running Terraform plan..."
                    echo "Domain: $DOMAIN_NAME"
                    echo "Region: $AWS_REGION"
                    echo "TF Var File: $TF_VAR_FILE"
                    
                    export PATH=$PWD:$PATH
                    terraform plan \
                        -var-file="$TF_VAR_FILE" \
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
            environment {
                DOMAIN_NAME = "${params.DOMAIN_NAME}"
                AWS_REGION = "${params.AWS_REGION}"
                TF_VAR_FILE = "regions/${params.AWS_REGION}/${params.DOMAIN_NAME}.tfvars"
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
                            export PATH=$PWD:$PATH
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
                        echo "❌ ERROR: backup-state-to-github.sh script not found"
                        exit 1
                    fi
                '''
            }
        }
    }
    
    post {
        always {
            script {
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
                    echo "✅ OpenSearch cluster '${params.DOMAIN_NAME}' successfully imported into Terraform management"
                } else if (params.OPERATION == 'apply') {
                    echo "✅ OpenSearch cluster '${params.DOMAIN_NAME}' changes applied successfully"
                } else if (params.OPERATION == 'plan') {
                    echo "✅ Terraform plan for '${params.DOMAIN_NAME}' completed successfully"
                } else if (params.OPERATION == 'validate') {
                    echo "✅ Terraform validation for '${params.DOMAIN_NAME}' completed successfully"
                } else if (params.OPERATION == 'backup-state') {
                    echo "✅ Terraform state backup completed successfully"
                }
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed during '${params.OPERATION}' operation for domain '${params.DOMAIN_NAME}'"
                echo "Check the logs above for detailed error information"
            }
        }
        
        cleanup {
            sh '''
                echo "Cleaning up temporary files..."
                rm -f terraform_1.6.0_darwin_amd64.zip
            '''
        }
    }
}