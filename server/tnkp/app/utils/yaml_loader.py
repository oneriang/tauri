# app/utils/yaml_loader.py
import yaml
from pathlib import Path

CONFIG_DIR = Path(__file__).parent.parent / "config" / "models"

def get_model_config(table_name):
    """根据表名读取对应的YAML配置"""
    config_path = CONFIG_DIR / f"{table_name}.yaml"
    if not config_path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")
    with open(config_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)['model']

def load_yaml_config(filename):
    config_path = CONFIG_DIR / filename
    with open(config_path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)
