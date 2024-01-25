FROM ubuntu:20.04

SHELL ["/bin/bash", "-c"]

RUN apt update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata

RUN apt update && apt install -y git curl make jq wget software-properties-common gnupg2 apt-transport-https ca-certificates

RUN wget https://go.dev/dl/go1.20.linux-amd64.tar.gz && tar xvzf go1.20.linux-amd64.tar.gz && cp go/bin/go /usr/bin/go && mv go /usr/lib && echo export GOROOT=/usr/lib/go >> ~/.bashrc

RUN curl -fsSL https://deb.nodesource.com/setup_16.x | /bin/bash

RUN apt install -y nodejs

RUN curl -L https://foundry.paradigm.xyz | /bin/bash

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | /bin/bash 

RUN export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && nvm install 16.9.0

RUN cd /root && git clone https://github.com/TrustlessComputer/optimism-tc.git

RUN cd /root/optimism-tc && npm install -g yarn && yarn install

RUN export PATH="$PATH:/root/.foundry/bin" && export GOROOT=/usr/lib/go && cd /root/optimism-tc && foundryup && /bin/bash -c make op-node op-batcher op-proposer && yarn build

RUN curl https://apt.releases.hashicorp.com/gpg | gpg --dearmor > hashicorp.gpg && install -o root -g root -m 644 hashicorp.gpg /etc/apt/trusted.gpg.d/

RUN apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main" && apt install -y terraform

RUN echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list 

RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

RUN apt update && apt install -y google-cloud-sdk 

RUN add-apt-repository --yes --update ppa:ansible/ansible

RUN apt install -y ansible

RUN cd /root && git clone --recurse-submodules -j4 https://github.com/180945/tc-contracts.git

RUN cd /root/tc-contracts && git checkout tags/0.1.3

RUN chmod +x /root/tc-contracts/deploy.sh

RUN cd /root && git clone --recurse-submodules -j4 https://github.com/180945/tc-swap-v3

RUN cd /root/tc-swap-v3 && git checkout tags/1.2

RUN chmod +x /root/tc-swap-v3/deploy.sh

ENTRYPOINT [ "bash" ]
