"""
Script para eliminar la configuración de LoadBalancer en un archivo YAML de kOps.
"""
import sys
import yaml  # type: ignore


def remove_loadbalancer(file_path):
    """
    Remove loadbalancer configuration from a kOps YAML file.

    Args:
        file_path (_type_): _description_
    """
    with open(file_path, 'r', encoding='utf-8') as file:
        docs = list(yaml.safe_load_all(file))

    for doc in docs:
        if doc and doc.get('kind') == 'Cluster':
            if 'spec' in doc and 'api' in doc['spec']:
                if 'loadBalancer' in doc['spec']['api']:
                    print(f"Borrando LoadBalancer de la configuracion de kOps {file_path}")
                    # Removemos el loadbalancer y obligamos a usar el DNS público (Gossip)
                    del doc['spec']['api']['loadBalancer']
                    doc['spec']['api']['dns'] = {}

    with open(file_path, 'w', encoding='utf-8') as file:
        yaml.safe_dump_all(docs, file, default_flow_style=False)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python3 remove_kops_lb.py <archivo.yaml>")
        sys.exit(1)
    remove_loadbalancer(sys.argv[1])
