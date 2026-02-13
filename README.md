# Terraform AWS – Déploiement EC2 (SSH sécurisé)

Ce repository contient une configuration **Terraform** pour déployer une **instance EC2** sur **AWS** (à partir d’une AMI), avec un **Security Group** autorisant l’accès **SSH** (port 22), idéalement limité à votre **IP publique**, et des **outputs** utiles (ID de l’instance, IP publique…).

---

## 🎯 Objectif
- Déployer rapidement une instance EC2 de test / lab via Terraform
- Avoir un accès SSH fonctionnel (et sécurisé)
- Garder un projet clair, versionné sur Git

---

## 🧩 Ressources AWS typiquement créées
Selon votre `main.tf`, ce projet peut inclure :
- `aws_instance` : instance EC2
- `aws_security_group` : règles réseau (ex : SSH)
- `aws_key_pair` : key pair pour SSH (si définie)
- `data.aws_vpc` / `data.aws_subnets` : récupération de VPC/Subnets existants
- `data.http` : récupération de l’IP publique (si utilisée pour limiter SSH)

> 💡 Les ressources exactes dépendent de votre fichier `main.tf`.

---

## ✅ Prérequis
### Outils
- **Terraform** (recommandé : version récente)
- **AWS CLI** ou accès **AWS SSO** configuré
- Git (optionnel mais recommandé)

### Accès AWS
Vous devez être authentifié(e) sur AWS et avoir les permissions nécessaires (au minimum) :
- EC2 (instances, keypairs)
- VPC (security groups, subnets, vpc)
- (Optionnel) accès à l’AMI utilisée

Vérifier l’accès :
```bash
aws sts get-caller-identity
