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
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh '''
                    if [ ! -d "$STATE_REPO_PATH" ]; then
                        git clone https://github.com/manideepyeredla1326/opensearch-ireland-infrastructure.git $STATE_REPO_PATH
                    else
                        cd $STATE_REPO_PATH && git pull origin main
                    fi
                '''
            }
        }
        
        stage('Setup Tools') {
            steps {
                sh '''
                    export PATH="$WORKSPACE/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

                    if ! command -v terraform &> /dev/null; then
                        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
                        ARCH=$(uname -m)
                        if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi
                        if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi

                        TF_ZIP="terraform_1.9.8_${OS}_${ARCH}.zip"
                        curl -LO "https://releases.hashicorp.com/terraform/1.9.8/${TF_ZIP}"
                        mkdir -p "$WORKSPACE/bin"
                        unzip -o "$TF_ZIP" -d "$WORKSPACE/bin"
                        chmod +x "$WORKSPACE/bin/terraform"
                        rm -f "$TF_ZIP"
                    fi

                    terraform version

                    if command -v aws &> /dev/null; then
                        echo "✅ AWS CLI found"
                        aws --version
                    else
                        echo "❌ AWS CLI not found in PATH, searching..."
                        AWS_PATH=$(find /usr/local /opt/homebrew /Users/myeredla -name "aws" -type f 2>/dev/null | head -1)
                        if [ -n "$AWS_PATH" ]; then
                            echo "✅ Found AWS CLI at: $AWS_PATH"
                            mkdir -p "$WORKSPACE/bin"
                            ln -sf "$AWS_PATH" "$WORKSPACE/bin/aws"
                            aws --version
                        else
                            echo "❌ AWS CLI not installed. Run: brew install awscli"
                            exit 1
                        fi
                    fi

                    echo "✅ All tools ready"
                '''
            }
        }
        
        stage('Import Existing Cluster') {
            when {
                expression { params.OPERATION == 'import' }
            }
            steps {
                sh """
                    export PATH="$WORKSPACE/bin:/usr/local/bin:/opt/homebrew/bin:\$PATH"
                    chmod +x scripts/import-existing-cluster.sh
                    ./scripts/import-existing-cluster.sh "${params.DOMAIN_NAME}" "${params.AWS_REGION}" "${env.TF_VAR_file}"
                """
            }
        }
        
        stage('Initialize') {
            when {
                expression { params.OPERATION in ['validate', 'plan', 'apply'] }
            }
            steps {
                dir('terraform') {
                    sh '''
                        export PATH="$WORKSPACE/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
                        terraform init -input=false
                    '''
                }
            }
        }
        
        stage('Validate') {
            when {
                expression { params.OPERATION == 'validate' }
            }
            steps {
                sh '''
                    chmod +x scripts/validate-deployment.sh
                    ./scripts/validate-deployment.sh
                '''
            }
        }
        
        stage('Plan') {
            when {
                expression { params.OPERATION in ['validate', 'plan', 'apply'] }
            }
            steps {
                dir('terraform') {
                    sh '''
                        export PATH="$WORKSPACE/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
                        terraform plan \
                            -var-file="../${TF_VAR_file}" \
                            -out=tfplan \
                            -input=false
                    '''
                }
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
                        dir('terraform') {
                            sh '''
                                export PATH="$WORKSPACE/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
                                terraform apply -input=false tfplan
                            '''
                        }
                        
                        sh '''
                            chmod +x scripts/backup-state-to-github.sh
                            ./scripts/backup-state-to-github.sh
                        '''
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
                    chmod +x scripts/backup-state-to-github.sh
                    ./scripts/backup-state-to-github.sh
                '''
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'backup-*.json', allowEmptyArchive: true
            archiveArtifacts artifacts: 'terraform/tfplan', allowEmptyArchive: true
        }
        
        success {
            script {
                if (params.OPERATION == 'import') {
                    echo "✅ OpenSearch cluster successfully imported into Terraform management"
                }
            }
        }
    }
}
