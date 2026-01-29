**MongoDB ReplicaSet + Spring Boot with Host Volume Mount (NO PV/PVC)**

```yaml
---
# MongoDB ReplicaSet with Host Volume
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: mongodbrs
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
      - name: mongo
        image: mongo:7.0
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: devdb
        - name: MONGO_INITDB_ROOT_PASSWORD
          value: devdb123
        - name: MONGO_INITDB_DATABASE
          value: myappdb
        volumeMounts:
        - name: mongo-host-storage
          mountPath: /data/db
      volumes:
      - name: mongo-host-storage
        hostPath:
          path: /mnt/mongo-data  # Host directory on node
          type: DirectoryOrCreate

---
# MongoDB Service
apiVersion: v1
kind: Service
metadata:
  name: mongosvc
spec:
  type: ClusterIP
  selector:
    app: mongo
  ports:
  - port: 27017
    targetPort: 27017

---
# Spring Boot Deployment - Individual ENV vars
apiVersion: apps/v1
kind: Deployment
metadata:
  name: springappdeployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: springapp
  template:
    metadata:
      labels:
        app: springapp
    spec:
      containers:
      - name: springapp
        image: dockeruma03/spring-boot-mongo:1
        ports:
        - containerPort: 8080
        env:
        # Standard Spring Boot MongoDB env vars
        - name: SPRING_DATA_MONGODB_HOST
          value: mongosvc
        - name: SPRING_DATA_MONGODB_PORT
          value: "27017"
        - name: SPRING_DATA_MONGODB_USERNAME
          value: devdb
        - name: SPRING_DATA_MONGODB_PASSWORD
          value: devdb123
        - name: SPRING_DATA_MONGODB_DATABASE
          value: myappdb
        - name: SPRING_DATA_MONGODB_AUTHENTICATION_DATABASE
          value: admin

---
# Spring Boot Service
apiVersion: v1
kind: Service
metadata:
  name: springappsvc
spec:
  type: NodePort
  selector:
    app: springapp
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 32577
```

## Pre-Deployment (On Node)
```bash
# Create host directory BEFORE deployment
sudo mkdir -p /mnt/mongo-data
sudo chmod 777 /mnt/mongo-data
sudo chown 999:999 /mnt/mongo-data  # MongoDB user/group ID
```

## Deploy
```bash
# Clean previous
kubectl delete all --all -l app=springapp,app=mongo

# Deploy
kubectl apply -f host-volume-app.yml
kubectl get all
```

## Key Features
✅ **Host Volume**: `/mnt/mongo-data` → `/data/db` (persists across pod restarts)  
✅ **ReplicaSet**: Simple MongoDB controller  
✅ **Individual ENV vars**: Standard Spring Boot format  
✅ **No PV/PVC**: Direct hostPath mount  
✅ **2 Spring replicas**: Load balanced  

## Data Persistence
- **MongoDB data**: Stored on node at `/mnt/mongo-data`
- **Survives**: Pod restarts, deletions, rescheduling
- **Node-specific**: Data tied to specific worker node

**Access**: `curl http://10.0.1.129:32577`

**Perfect for development/single-node clusters** - persistent data without complex storage classes! 🎉
