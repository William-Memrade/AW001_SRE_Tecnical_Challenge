import sys
import yaml

def remove_loadbalancer(file_path):
    with open(file_path, 'r') as file:
        docs = list(yaml.safe_load_all(file))

    for doc in docs:
        if doc and doc.get('kind') == 'Cluster':
            if 'spec' in doc and 'api' in doc['spec']:
                if 'loadBalancer' in doc['spec']['api']:
                    print(f"Borrando LoadBalancer de la configuracion de kOps {file_path}")
                    # Removemos el loadbalancer y obligamos a usar el DNS público (Gossip)
                    del doc['spec']['api']['loadBalancer']
                    doc['spec']['api']['dns'] = {}

    with open(file_path, 'w') as file:
        yaml.safe_dump_all(docs, file, default_flow_style=False)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python3 remove_kops_lb.py <archivo.yaml>")
        sys.exit(1)
    remove_loadbalancer(sys.argv[1])
