---
title: "Istio Ingress Gateway中的Envoy Listener和Route解析"
date: 2018-10-15T15:24:37+08:00
draft: false
banner: "https://ws4.sinaimg.cn/large/006tNbRwly1fw867vtusqj30rs0kudth.jpg"
author: "沈旭光"
authorlink: "https://github.com/shenxg13/istio-no-best-practice"
originallink: "https://github.com/shenxg13/istio-no-best-practice/blob/master/summary-control-traffic-using-gateway-in-istio.md"
summary: "本文重点为分析Istio Gateway以及相关VirtualService配置是如何生成Istio Ingress Gateway的Envoy相关Listener和Route规则。"
tags: ["Ingress-Gateway"]
categories: ["istio"]
keywords: ["service mesh","服务网格","ingress gateway"]
---

![](https://ws2.sinaimg.cn/large/006tNbRwly1fw7vchevggj30xu0cwq5i.jpg)



## 非TLS单主机环境

### 相关拓扑

![](https://ws4.sinaimg.cn/large/006tNbRwly1fw7h9huwyqj31kw29gnpd.jpg)

- 在集群外配置ipvs作为ingress gateway的负载均衡器。
- ipvs lb的地址为192.168.0.62，这个ip地址会作为用户访问的ip地址，也就是virtualservice中虚拟主机的地址。
- 将istio ingress gateway service的external ip设置为192.168.0.62。
- 增加gateway定义。
- gateway定义中的selector会将该设置与相应的gateway pod绑定。
- gateway定义中的servers会在相应的pod中生成listener实例，该拓扑中的监听端口为6280。
- 需要将6280端口注册到该gateway pod对应的服务中。
- gateway定义中的hosts表示listener会向哪些特定的虚拟主机转发流量。
- 增加virtualservice定义。
- virtualservice定义中的hosts与gateway中的hosts相对应表示该服务可以注册到gateway的监听中，这个host写会更新到gateway pod路由表的虚拟主机条目中。
- virtualservice定义中的gateways将virtualservice与gateway关联起来。
- virtualservice定义中的http定义了路由规则，路由规则会写入到相应gateway pod的路由表中。
- gateway pod的监听和路由会通过端口号绑定在一起。



### 相关配置

```bash
ipvsadm -A -t 192.168.0.62:6280 -s wrr -p 300
ipvsadm -a -t 192.168.0.62:6280 -r 192.168.0.72:6280 -g
ipvsadm -a -t 192.168.0.62:6280 -r 192.168.0.73:6280 -g
```

- ipvs相关配置。



```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation
  servers:
  - port:
      number: 6280
      name: http
      protocol: HTTP
    hosts:
    - "192.168.0.62"
```

- gateway相关配置。



```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin-vs
spec:
  hosts:
  - "192.168.0.62"
  gateways:
  - httpbin-gateway
  http:
  - match:
    - uri:
        prefix: /status
    - uri:
        prefix: /delay
    - uri:
        prefix: /headers
    route:
    - destination:
        port:
          number: 8000
        host: httpbin
```

- virtualservice相关配置。



## TLS单主机环境

### 相关拓扑

![](https://ws4.sinaimg.cn/large/006tNbRwly1fw7vl2suq5j31kw2hk4qq.jpg)

- 增加gateway定义。
- gateway定义中包括80和443。
- 在80中启用httpsredirect。
- 在443中启用simple tls。
- 指定443的key和cert。



### 相关配置

```bash
ipvsadm -A -t 192.168.0.62:443 -s wrr -p 300
ipvsadm -a -t 192.168.0.62:443 -r 192.168.0.72:443 -g
ipvsadm -a -t 192.168.0.62:443 -r 192.168.0.73:443 -g
ipvsadm -A -t 192.168.0.62:80 -s wrr -p 300
ipvsadm -a -t 192.168.0.62:80 -r 192.168.0.72:80 -g
ipvsadm -a -t 192.168.0.62:80 -r 192.168.0.73:80 -g
```

- ipvs相关配置。



```bash
openssl req \
-newkey rsa:4096 -nodes -sha256 -keyout ca.key \
-x509 -days 3655 -out ca.crt

openssl req \
-newkey rsa:4096 -nodes -sha256 -keyout istio-httpbin.key \
-out istio-httpbin.csr

echo subjectAltName = IP:192.168.0.62, IP:192.168.0.72, IP:192.168.0.73, DNS:httpbin.istio.local, DNS:app.istio.local > extfile.cnf

openssl x509 \
-req -days 3655 -in istio-httpbin.csr -CA ca.crt -CAkey ca.key \
-CAcreateserial -extfile extfile.cnf -out istio-httpbin.crt
```

- 自签名证书相关配置。



```bash
kubectl create -n istio-system secret tls istio-ingressgateway-certs --key ./istio-httpbin.key --cert ./istio-httpbin.crt
```

- k8s secret相关配置。



```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpbin-gateway-tls
spec:
  selector:
    istio: ingressgateway # use istio default ingress gateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      serverCertificate: /etc/istio/ingressgateway-certs/tls.crt
      privateKey: /etc/istio/ingressgateway-certs/tls.key
    hosts:
    - "*"
```

- gateway相关配置。



```yaml
kind: VirtualService
metadata:
  name: httpbin-vs
spec:
  hosts:
  - "192.168.0.62"
  gateways:
  - httpbin-gateway-tls
  http:
  - match:
    - uri:
        prefix: /status
    - uri:
        prefix: /delay
    - uri:
        prefix: /headers
    route:
    - destination:
        port:
          number: 8000
        host: httpbin
```

- virtualservice相关配置。



```json
[~/K8s/istio/istio-1.0.2/samples/httpbin]$ istioctl pc listener istio-ingressgateway-7c97674c9c-xfpqt -n istio-system -o json
[
    {
        "name": "0.0.0.0_443",
        "address": {
            "socketAddress": {
                "address": "0.0.0.0",
                "portValue": 443
            }
        },
        "filterChains": [
            {
                "tlsContext": {
                    "commonTlsContext": {
                        "tlsCertificates": [
                            {
                                "certificateChain": {
                                    "filename": "/etc/istio/ingressgateway-certs/tls.crt"
                                },
                                "privateKey": {
                                    "filename": "/etc/istio/ingressgateway-certs/tls.key"
                                }
                            }
                        ],
                        "alpnProtocols": [
                            "h2",
                            "http/1.1"
                        ]
                    },
                    "requireClientCertificate": false
                },
                "filters": [
                    {
                        "name": "envoy.http_connection_manager",
                        "config": {
                            "access_log": [
                                {
                                    "config": {
                                        "path": "/dev/stdout"
                                    },
                                    "name": "envoy.file_access_log"
                                }
                            ],
                            "generate_request_id": true,
                            "http_filters": [
                                {
                                    "config": {
                                        "default_destination_service": "default",
                                        "forward_attributes": {
                                            "attributes": {
                                                "source.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7c97674c9c-xfpqt.istio-system"
                                                }
                                            }
                                        },
                                        "mixer_attributes": {
                                            "attributes": {
                                                "context.reporter.kind": {
                                                    "string_value": "outbound"
                                                },
                                                "context.reporter.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7c97674c9c-xfpqt.istio-system"
                                                },
                                                "source.namespace": {
                                                    "string_value": "istio-system"
                                                },
                                                "source.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7c97674c9c-xfpqt.istio-system"
                                                }
                                            }
                                        },
                                        "service_configs": {
                                            "default": {}
                                        },
                                        "transport": {
                                            "attributes_for_mixer_proxy": {
                                                "attributes": {
                                                    "source.uid": {
                                                        "string_value": "kubernetes://istio-ingressgateway-7c97674c9c-xfpqt.istio-system"
                                                    }
                                                }
                                            },
                                            "check_cluster": "outbound|9091||istio-policy.istio-system.svc.cluster.local",
                                            "network_fail_policy": {
                                                "policy": "FAIL_CLOSE"
                                            },
                                            "report_cluster": "outbound|9091||istio-telemetry.istio-system.svc.cluster.local"
                                        }
                                    },
                                    "name": "mixer"
                                },
                                {
                                    "name": "envoy.cors"
                                },
                                {
                                    "name": "envoy.fault"
                                },
                                {
                                    "name": "envoy.router"
                                }
                            ],
                            "rds": {
                                "config_source": {
                                    "ads": {}
                                },
                                "route_config_name": "https.443.https"
                            },
                            "stat_prefix": "0.0.0.0_443",
                            "stream_idle_timeout": "0.000s",
                            "tracing": {
                                "client_sampling": {
                                    "value": 100
                                },
                                "operation_name": "EGRESS",
                                "overall_sampling": {
                                    "value": 100
                                },
                                "random_sampling": {
                                    "value": 100
                                }
                            },
                            "upgrade_configs": [
                                {
                                    "upgrade_type": "websocket"
                                }
                            ],
                            "use_remote_address": true
                        }
                    }
                ]
            }
        ]
    },
    {
        "name": "0.0.0.0_80",
        "address": {
            "socketAddress": {
                "address": "0.0.0.0",
                "portValue": 80
            }
        },
        "filterChains": [
            {
                "filters": [
                    {
                        "name": "envoy.http_connection_manager",
                        "config": {
                            "access_log": [
                                {
                                    "config": {
                                        "path": "/dev/stdout"
                                    },
                                    "name": "envoy.file_access_log"
                                }
                            ],
                            "generate_request_id": true,
                            "http_filters": [
                                {
                                    "config": {
                                        "default_destination_service": "default",
                                        "forward_attributes": {
                                            "attributes": {
                                                "source.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7c97674c9c-xfpqt.istio-system"
                                                }
                                            }
                                        },
                                        "mixer_attributes": {
                                            "attributes": {
                                                "context.reporter.kind": {
                                                    "string_value": "outbound"
                                                },
                                                "context.reporter.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7c97674c9c-xfpqt.istio-system"
                                                },
                                                "source.namespace": {
                                                    "string_value": "istio-system"
                                                },
                                                "source.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7c97674c9c-xfpqt.istio-system"
                                                }
                                            }
                                        },
                                        "service_configs": {
                                            "default": {}
                                        },
                                        "transport": {
                                            "attributes_for_mixer_proxy": {
                                                "attributes": {
                                                    "source.uid": {
                                                        "string_value": "kubernetes://istio-ingressgateway-7c97674c9c-xfpqt.istio-system"
                                                    }
                                                }
                                            },
                                            "check_cluster": "outbound|9091||istio-policy.istio-system.svc.cluster.local",
                                            "network_fail_policy": {
                                                "policy": "FAIL_CLOSE"
                                            },
                                            "report_cluster": "outbound|9091||istio-telemetry.istio-system.svc.cluster.local"
                                        }
                                    },
                                    "name": "mixer"
                                },
                                {
                                    "name": "envoy.cors"
                                },
                                {
                                    "name": "envoy.fault"
                                },
                                {
                                    "name": "envoy.router"
                                }
                            ],
                            "rds": {
                                "config_source": {
                                    "ads": {}
                                },
                                "route_config_name": "http.80"
                            },
                            "stat_prefix": "0.0.0.0_80",
                            "stream_idle_timeout": "0.000s",
                            "tracing": {
                                "client_sampling": {
                                    "value": 100
                                },
                                "operation_name": "EGRESS",
                                "overall_sampling": {
                                    "value": 100
                                },
                                "random_sampling": {
                                    "value": 100
                                }
                            },
                            "upgrade_configs": [
                                {
                                    "upgrade_type": "websocket"
                                }
                            ],
                            "use_remote_address": true
                        }
                    }
                ]
            }
        ]
    }
]
[~/K8s/istio/istio-1.0.2/samples/httpbin]$
```

- gateway envoy listener相关配置。



```json
[~/K8s/istio/istio-1.0.2/samples/httpbin]$ istioctl pc route istio-ingressgateway-7c97674c9c-xfpqt -n istio-system -o json
[
    {
        "name": "https.443.https",
        "virtualHosts": [
            {
                "name": "192.168.0.62:443",
                "domains": [
                    "192.168.0.62",
                    "192.168.0.62:443"
                ],
                "routes": [
                    {
                        "match": {
                            "prefix": "/status"
                        },
                        "route": {
                            "cluster": "outbound|8000||httpbin.default.svc.cluster.local",
                            "timeout": "0.000s",
                            "maxGrpcTimeout": "0.000s"
                        },
                        "decorator": {
                            "operation": "httpbin.default.svc.cluster.local:8000/status*"
                        },
                        "perFilterConfig": {
                            "mixer": {
                                "forward_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                },
                                "mixer_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    {
                        "match": {
                            "prefix": "/delay"
                        },
                        "route": {
                            "cluster": "outbound|8000||httpbin.default.svc.cluster.local",
                            "timeout": "0.000s",
                            "maxGrpcTimeout": "0.000s"
                        },
                        "decorator": {
                            "operation": "httpbin.default.svc.cluster.local:8000/delay*"
                        },
                        "perFilterConfig": {
                            "mixer": {
                                "forward_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                },
                                "mixer_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    {
                        "match": {
                            "prefix": "/headers"
                        },
                        "route": {
                            "cluster": "outbound|8000||httpbin.default.svc.cluster.local",
                            "timeout": "0.000s",
                            "maxGrpcTimeout": "0.000s"
                        },
                        "decorator": {
                            "operation": "httpbin.default.svc.cluster.local:8000/headers*"
                        },
                        "perFilterConfig": {
                            "mixer": {
                                "forward_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                },
                                "mixer_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                }
                            }
                        }
                    }
                ]
            }
        ],
        "validateClusters": false
    },
    {
        "name": "http.80",
        "virtualHosts": [
            {
                "name": "192.168.0.62:80",
                "domains": [
                    "192.168.0.62",
                    "192.168.0.62:80"
                ],
                "routes": [
                    {
                        "match": {
                            "prefix": "/status"
                        },
                        "route": {
                            "cluster": "outbound|8000||httpbin.default.svc.cluster.local",
                            "timeout": "0.000s",
                            "maxGrpcTimeout": "0.000s"
                        },
                        "decorator": {
                            "operation": "httpbin.default.svc.cluster.local:8000/status*"
                        },
                        "perFilterConfig": {
                            "mixer": {
                                "forward_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                },
                                "mixer_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    {
                        "match": {
                            "prefix": "/delay"
                        },
                        "route": {
                            "cluster": "outbound|8000||httpbin.default.svc.cluster.local",
                            "timeout": "0.000s",
                            "maxGrpcTimeout": "0.000s"
                        },
                        "decorator": {
                            "operation": "httpbin.default.svc.cluster.local:8000/delay*"
                        },
                        "perFilterConfig": {
                            "mixer": {
                                "forward_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                },
                                "mixer_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    {
                        "match": {
                            "prefix": "/headers"
                        },
                        "route": {
                            "cluster": "outbound|8000||httpbin.default.svc.cluster.local",
                            "timeout": "0.000s",
                            "maxGrpcTimeout": "0.000s"
                        },
                        "decorator": {
                            "operation": "httpbin.default.svc.cluster.local:8000/headers*"
                        },
                        "perFilterConfig": {
                            "mixer": {
                                "forward_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                },
                                "mixer_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                }
                            }
                        }
                    }
                ],
                "requireTls": "ALL"
            }
        ],
        "validateClusters": false
    }
]
[~/K8s/istio/istio-1.0.2/samples/httpbin]$
```

- gateway envoy route相关配置。



```bash
[~/K8s/istio/istio-1.0.2/samples/certs]$ http http://192.168.0.62/status/418 --verify no --follow -v
GET /status/418 HTTP/1.1
Accept: */*
Accept-Encoding: gzip, deflate
Connection: keep-alive
Host: 192.168.0.62
User-Agent: HTTPie/0.9.9

HTTP/1.1 301 Moved Permanently
content-length: 0
date: Sun, 30 Sep 2018 09:04:21 GMT
location: https://192.168.0.62/status/418
server: envoy

GET /status/418 HTTP/1.1
Accept: */*
Accept-Encoding: gzip, deflate
Connection: keep-alive
Host: 192.168.0.62
User-Agent: HTTPie/0.9.9

HTTP/1.1 418 Unknown
access-control-allow-credentials: true
access-control-allow-origin: *
content-length: 135
date: Sun, 30 Sep 2018 09:04:21 GMT
server: envoy
x-envoy-upstream-service-time: 2
x-more-info: http://tools.ietf.org/html/rfc2324

    -=[ teapot ]=-

       _...._
     .'  _ _ `.
    | ."` ^ `". _,
    \_;`"---"`|//
      |       ;/
      \_     _/
        `"""`

[~/K8s/istio/istio-1.0.2/samples/certs]$
```

- httpredirect测试结果。



```bash
[~/K8s/istio/istio-1.0.2/samples/certs]$ http https://192.168.0.62/status/418 --verify no -v
GET /status/418 HTTP/1.1
Accept: */*
Accept-Encoding: gzip, deflate
Connection: keep-alive
Host: 192.168.0.62
User-Agent: HTTPie/0.9.9

HTTP/1.1 418 Unknown
access-control-allow-credentials: true
access-control-allow-origin: *
content-length: 135
date: Sun, 30 Sep 2018 09:06:07 GMT
server: envoy
x-envoy-upstream-service-time: 7
x-more-info: http://tools.ietf.org/html/rfc2324

    -=[ teapot ]=-

       _...._
     .'  _ _ `.
    | ."` ^ `". _,
    \_;`"---"`|//
      |       ;/
      \_     _/
        `"""`

[~/K8s/istio/istio-1.0.2/samples/certs]$
```

- https测试结果。



## mTLS单主机环境

### 相关拓扑

![](https://ws3.sinaimg.cn/large/006tNbRwly1fw7vowvpd2j31kw2i5e82.jpg)

- 增加gateway定义。
- gateway定义中包括443。
- 在443中启用mutual tls。
- 指定443的key和cert。
- 指定443的ca cert。
- 指定允许连接443的san。



### 相关配置

```bash
openssl req \
-newkey rsa:4096 -nodes -sha256 -keyout istio-is5.key \
-out istio-is5.csr

echo subjectAltName = DNS:is5.istio.local > is5-extfile.cnf

openssl x509 \
-req -days 3655 -in istio-is5.csr -CA ca.crt -CAkey ca.key \
-CAcreateserial -extfile is5-extfile.cnf -out istio-is5.crt
```

- client自签名证书相关配置。



```bash
kubectl create -n istio-system secret generic istio-ingressgateway-ca-certs --from-file ./ca.crt
```

- k8s secret相关配置。



```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpbin-gateway-mtls
spec:
  selector:
    istio: ingressgateway # use istio default ingress gateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: MUTUAL
      serverCertificate: /etc/istio/ingressgateway-certs/tls.crt
      privateKey: /etc/istio/ingressgateway-certs/tls.key
      caCertificates: /etc/istio/ingressgateway-ca-certs/ca.crt
      subjectAltNames:
      - is5.istio.local
    hosts:
    - "*"
```

- gateway相关配置。



```yaml
kind: VirtualService
metadata:
  name: httpbin-vs
spec:
  hosts:
  - "192.168.0.62"
  gateways:
  - httpbin-gateway-mtls
  http:
  - match:
    - uri:
        prefix: /status
    - uri:
        prefix: /delay
    - uri:
        prefix: /headers
    route:
    - destination:
        port:
          number: 8000
        host: httpbin
```

- virtualservice相关配置。



```json
[~/K8s/istio/istio-1.0.2/samples/httpbin]$ istioctl pc listener istio-ingressgateway-7c97674c9c-xfpqt -n istio-system -o json
[
    {
        "name": "0.0.0.0_443",
        "address": {
            "socketAddress": {
                "address": "0.0.0.0",
                "portValue": 443
            }
        },
        "filterChains": [
            {
                "tlsContext": {
                    "commonTlsContext": {
                        "tlsCertificates": [
                            {
                                "certificateChain": {
                                    "filename": "/etc/istio/ingressgateway-certs/tls.crt"
                                },
                                "privateKey": {
                                    "filename": "/etc/istio/ingressgateway-certs/tls.key"
                                }
                            }
                        ],
                        "validationContext": {
                            "trustedCa": {
                                "filename": "/etc/istio/ingressgateway-ca-certs/ca.crt"
                            },
                            "verifySubjectAltName": [
                                "is5.istio.local"
                            ]
                        },
                        "alpnProtocols": [
                            "h2",
                            "http/1.1"
                        ]
                    },
                    "requireClientCertificate": true
                },
                "filters": [
                    {
                        "name": "envoy.http_connection_manager",
                        "config": {
                            "access_log": [
                                {
                                    "config": {
                                        "path": "/dev/stdout"
                                    },
                                    "name": "envoy.file_access_log"
                                }
                            ],
                            "generate_request_id": true,
                            "http_filters": [
                                {
                                    "config": {
                                        "default_destination_service": "default",
                                        "forward_attributes": {
                                            "attributes": {
                                                "source.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7c97674c9c-xfpqt.istio-system"
                                                }
                                            }
                                        },
                                        "mixer_attributes": {
                                            "attributes": {
                                                "context.reporter.kind": {
                                                    "string_value": "outbound"
                                                },
                                                "context.reporter.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7c97674c9c-xfpqt.istio-system"
                                                },
                                                "source.namespace": {
                                                    "string_value": "istio-system"
                                                },
                                                "source.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7c97674c9c-xfpqt.istio-system"
                                                }
                                            }
                                        },
                                        "service_configs": {
                                            "default": {}
                                        },
                                        "transport": {
                                            "attributes_for_mixer_proxy": {
                                                "attributes": {
                                                    "source.uid": {
                                                        "string_value": "kubernetes://istio-ingressgateway-7c97674c9c-xfpqt.istio-system"
                                                    }
                                                }
                                            },
                                            "check_cluster": "outbound|9091||istio-policy.istio-system.svc.cluster.local",
                                            "network_fail_policy": {
                                                "policy": "FAIL_CLOSE"
                                            },
                                            "report_cluster": "outbound|9091||istio-telemetry.istio-system.svc.cluster.local"
                                        }
                                    },
                                    "name": "mixer"
                                },
                                {
                                    "name": "envoy.cors"
                                },
                                {
                                    "name": "envoy.fault"
                                },
                                {
                                    "name": "envoy.router"
                                }
                            ],
                            "rds": {
                                "config_source": {
                                    "ads": {}
                                },
                                "route_config_name": "https.443.https"
                            },
                            "stat_prefix": "0.0.0.0_443",
                            "stream_idle_timeout": "0.000s",
                            "tracing": {
                                "client_sampling": {
                                    "value": 100
                                },
                                "operation_name": "EGRESS",
                                "overall_sampling": {
                                    "value": 100
                                },
                                "random_sampling": {
                                    "value": 100
                                }
                            },
                            "upgrade_configs": [
                                {
                                    "upgrade_type": "websocket"
                                }
                            ],
                            "use_remote_address": true
                        }
                    }
                ]
            }
        ]
    }
]
[~/K8s/istio/istio-1.0.2/samples/httpbin]$
```

- gateway envoy listener相关配置。



```json
[~/K8s/istio/istio-1.0.2/samples/httpbin]$ istioctl pc route istio-ingressgateway-7c97674c9c-xfpqt -n istio-system -o json
[
    {
        "name": "https.443.https",
        "virtualHosts": [
            {
                "name": "192.168.0.62:443",
                "domains": [
                    "192.168.0.62",
                    "192.168.0.62:443"
                ],
                "routes": [
                    {
                        "match": {
                            "prefix": "/status"
                        },
                        "route": {
                            "cluster": "outbound|8000||httpbin.default.svc.cluster.local",
                            "timeout": "0.000s",
                            "maxGrpcTimeout": "0.000s"
                        },
                        "decorator": {
                            "operation": "httpbin.default.svc.cluster.local:8000/status*"
                        },
                        "perFilterConfig": {
                            "mixer": {
                                "forward_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                },
                                "mixer_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    {
                        "match": {
                            "prefix": "/delay"
                        },
                        "route": {
                            "cluster": "outbound|8000||httpbin.default.svc.cluster.local",
                            "timeout": "0.000s",
                            "maxGrpcTimeout": "0.000s"
                        },
                        "decorator": {
                            "operation": "httpbin.default.svc.cluster.local:8000/delay*"
                        },
                        "perFilterConfig": {
                            "mixer": {
                                "forward_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                },
                                "mixer_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    {
                        "match": {
                            "prefix": "/headers"
                        },
                        "route": {
                            "cluster": "outbound|8000||httpbin.default.svc.cluster.local",
                            "timeout": "0.000s",
                            "maxGrpcTimeout": "0.000s"
                        },
                        "decorator": {
                            "operation": "httpbin.default.svc.cluster.local:8000/headers*"
                        },
                        "perFilterConfig": {
                            "mixer": {
                                "forward_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                },
                                "mixer_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin"
                                        }
                                    }
                                }
                            }
                        }
                    }
                ]
            }
        ],
        "validateClusters": false
    }
]
[~/K8s/istio/istio-1.0.2/samples/httpbin]$
```

- gateway envoy route相关配置。



```bash
[~/K8s/istio/istio-1.0.2/samples/certs]$ http https://192.168.0.62/status/418 --verify no --cert ./istio-is5.crt --cert-key ./istio-is5.key -v
GET /status/418 HTTP/1.1
Accept: */*
Accept-Encoding: gzip, deflate
Connection: keep-alive
Host: 192.168.0.62
User-Agent: HTTPie/0.9.9

HTTP/1.1 418 Unknown
access-control-allow-credentials: true
access-control-allow-origin: *
content-length: 135
date: Sun, 30 Sep 2018 09:34:54 GMT
server: envoy
x-envoy-upstream-service-time: 6
x-more-info: http://tools.ietf.org/html/rfc2324

    -=[ teapot ]=-

       _...._
     .'  _ _ `.
    | ."` ^ `". _,
    \_;`"---"`|//
      |       ;/
      \_     _/
        `"""`

[~/K8s/istio/istio-1.0.2/samples/certs]$
```

- 测试结果。



## 非TLS多主机环境

### 相关拓扑

![](https://ws4.sinaimg.cn/large/006tNbRwly1fw7vtk7zq4j31kw3o84qr.jpg)

- 使用azure aks环境。
- 2个域名，分别为：httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io和httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io。
- 为2个域名配置统一的gateway定义。
- 为2个域名分别配置virtualservice定义。
- 域名httpbin-a被路由至pod httpbin-a的/status uri。
- 域名httpbin-b被路由至pod httpbin-b的/headers uri。
- 在gateway的listnener中生成统一的监听0.0.0.0_80。
- 在gateway的route中分别生成针对httpbin-a和httpbin-b的虚拟主机。



### 相关配置

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpbin-dual-gateway
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation
  servers:
  - port:
      number: 80
      name: http-httpbin
      protocol: HTTP
    hosts:
    - "httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io"
    - "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io"

apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpbin-dual-gateway
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation
  servers:
  - port:
      number: 80
      name: http-httpbina
      protocol: HTTP
    hosts:
    - "httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io"
  - port:
      number: 80
      name: http-httpbinb
      protocol: HTTP
    hosts:
    - "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io"
```

- gateway相关配置。
- 这2个gateway的配置，生成的envoy配置是一致的。



```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin-a-vs
spec:
  hosts:
  - "httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io"
  gateways:
  - httpbin-dual-gateway
  http:
  - match:
    - uri:
        prefix: /status
    route:
    - destination:
        port:
          number: 8000
        host: httpbin-a

apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin-b-vs
spec:
  hosts:
  - "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io"
  gateways:
  - httpbin-dual-gateway
  http:
  - match:
    - uri:
        prefix: /headers
    route:
    - destination:
        port:
          number: 8000
        host: httpbin-b
```

- httpbin-a和httpbin-b的virtualservice相关配置。



```json
[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$ istioctl pc listener istio-ingressgateway-7ffb59776b-bn2sv -n istio-system -o json
[
    {
        "name": "0.0.0.0_80",
        "address": {
            "socketAddress": {
                "address": "0.0.0.0",
                "portValue": 80
            }
        },
        "filterChains": [
            {
                "filters": [
                    {
                        "name": "envoy.http_connection_manager",
                        "config": {
                            "access_log": [
                                {
                                    "config": {
                                        "path": "/dev/stdout"
                                    },
                                    "name": "envoy.file_access_log"
                                }
                            ],
                            "generate_request_id": true,
                            "http_filters": [
                                {
                                    "config": {
                                        "default_destination_service": "default",
                                        "forward_attributes": {
                                            "attributes": {
                                                "source.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7ffb59776b-bn2sv.istio-system"
                                                }
                                            }
                                        },
                                        "mixer_attributes": {
                                            "attributes": {
                                                "context.reporter.kind": {
                                                    "string_value": "outbound"
                                                },
                                                "context.reporter.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7ffb59776b-bn2sv.istio-system"
                                                },
                                                "source.namespace": {
                                                    "string_value": "istio-system"
                                                },
                                                "source.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7ffb59776b-bn2sv.istio-system"
                                                }
                                            }
                                        },
                                        "service_configs": {
                                            "default": {}
                                        },
                                        "transport": {
                                            "attributes_for_mixer_proxy": {
                                                "attributes": {
                                                    "source.uid": {
                                                        "string_value": "kubernetes://istio-ingressgateway-7ffb59776b-bn2sv.istio-system"
                                                    }
                                                }
                                            },
                                            "check_cluster": "outbound|9091||istio-policy.istio-system.svc.cluster.local",
                                            "network_fail_policy": {
                                                "policy": "FAIL_CLOSE"
                                            },
                                            "report_cluster": "outbound|9091||istio-telemetry.istio-system.svc.cluster.local"
                                        }
                                    },
                                    "name": "mixer"
                                },
                                {
                                    "name": "envoy.cors"
                                },
                                {
                                    "name": "envoy.fault"
                                },
                                {
                                    "name": "envoy.router"
                                }
                            ],
                            "rds": {
                                "config_source": {
                                    "ads": {}
                                },
                                "route_config_name": "http.80"
                            },
                            "stat_prefix": "0.0.0.0_80",
                            "stream_idle_timeout": "0.000s",
                            "tracing": {
                                "client_sampling": {
                                    "value": 100
                                },
                                "operation_name": "EGRESS",
                                "overall_sampling": {
                                    "value": 100
                                },
                                "random_sampling": {
                                    "value": 100
                                }
                            },
                            "upgrade_configs": [
                                {
                                    "upgrade_type": "websocket"
                                }
                            ],
                            "use_remote_address": true
                        }
                    }
                ]
            }
        ]
    }
]
[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$
```

- gateway envoy listener相关配置。



```json
[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$ istioctl pc route istio-ingressgateway-7ffb59776b-bn2sv -n istio-system -o json
[
    {
        "name": "http.80",
        "virtualHosts": [
            {
                "name": "httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io:80",
                "domains": [
                    "httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io",
                    "httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io:80"
                ],
                "routes": [
                    {
                        "match": {
                            "prefix": "/status"
                        },
                        "route": {
                            "cluster": "outbound|8000||httpbin-a.default.svc.cluster.local",
                            "timeout": "0.000s",
                            "maxGrpcTimeout": "0.000s"
                        },
                        "decorator": {
                            "operation": "httpbin-a.default.svc.cluster.local:8000/status*"
                        },
                        "perFilterConfig": {
                            "mixer": {
                                "forward_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin-a.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin-a.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin-a"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin-a"
                                        }
                                    }
                                },
                                "mixer_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin-a.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin-a.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin-a"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin-a"
                                        }
                                    }
                                }
                            }
                        }
                    }
                ]
            },
            {
                "name": "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io:80",
                "domains": [
                    "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io",
                    "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io:80"
                ],
                "routes": [
                    {
                        "match": {
                            "prefix": "/headers"
                        },
                        "route": {
                            "cluster": "outbound|8000||httpbin-b.default.svc.cluster.local",
                            "timeout": "0.000s",
                            "maxGrpcTimeout": "0.000s"
                        },
                        "decorator": {
                            "operation": "httpbin-b.default.svc.cluster.local:8000/headers*"
                        },
                        "perFilterConfig": {
                            "mixer": {
                                "forward_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin-b.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin-b.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin-b"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin-b"
                                        }
                                    }
                                },
                                "mixer_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin-b.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin-b.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin-b"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin-b"
                                        }
                                    }
                                }
                            }
                        }
                    }
                ]
            }
        ],
        "validateClusters": false
    }
]
[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$
```

- gateway envoy route相关配置。



```bash
[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$ http http://httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io:80/status/418
HTTP/1.1 418 Unknown
access-control-allow-credentials: true
access-control-allow-origin: *
content-length: 135
date: Thu, 11 Oct 2018 16:05:06 GMT
server: envoy
x-envoy-upstream-service-time: 3
x-more-info: http://tools.ietf.org/html/rfc2324

    -=[ teapot ]=-

       _...._
     .'  _ _ `.
    | ."` ^ `". _,
    \_;`"---"`|//
      |       ;/
      \_     _/
        `"""`

[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$ http http://httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io:80/headers
HTTP/1.1 200 OK
access-control-allow-credentials: true
access-control-allow-origin: *
content-length: 1012
content-type: application/json
date: Thu, 11 Oct 2018 16:05:24 GMT
server: envoy
x-envoy-upstream-service-time: 6

{
    "headers": {
        "Accept": "*/*",
        "Accept-Encoding": "gzip, deflate",
        "Content-Length": "0",
        "Host": "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io",
        "User-Agent": "HTTPie/0.9.9",
        "X-B3-Sampled": "1",
        "X-B3-Spanid": "4195f6aea35738e1",
        "X-B3-Traceid": "4195f6aea35738e1",
        "X-Envoy-Decorator-Operation": "httpbin-b.default.svc.cluster.local:8000/headers*",
        "X-Envoy-Internal": "true",
        "X-Istio-Attributes": "CioKHWRlc3RpbmF0aW9uLnNlcnZpY2UubmFtZXNwYWNlEgkSB2RlZmF1bHQKJwoYZGVzdGluYXRpb24uc2VydmljZS5uYW1lEgsSCWh0dHBiaW4tYgo8ChNkZXN0aW5hdGlvbi5zZXJ2aWNlEiUSI2h0dHBiaW4tYi5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsCk8KCnNvdXJjZS51aWQSQRI/a3ViZXJuZXRlczovL2lzdGlvLWluZ3Jlc3NnYXRld2F5LTdmZmI1OTc3NmItYm4yc3YuaXN0aW8tc3lzdGVtCj8KF2Rlc3RpbmF0aW9uLnNlcnZpY2UudWlkEiQSImlzdGlvOi8vZGVmYXVsdC9zZXJ2aWNlcy9odHRwYmluLWIKQQoYZGVzdGluYXRpb24uc2VydmljZS5ob3N0EiUSI2h0dHBiaW4tYi5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2Fs",
        "X-Request-Id": "63466f3e-23ae-9bf2-9c37-0dc4236551c9"
    }
}

[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$
```

- 测试结果。



## TLS多主机环境

### 相关拓扑

![](https://ws3.sinaimg.cn/large/006tNbRwly1fw7vwoggx6j31kw3nx4qs.jpg)

- 使用azure aks环境。
- 2个域名，分别为：httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io和httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io。
- 为2个域名分别配置gateway中的server定义。
- 为2个域名的server定义中增加证书的定义，每个server使用不同的证书。
- 为2个域名分别配置virtualservice定义。
- 在gateway的listnener中生成统一的监听0.0.0.0_443。
- 因为gateway中配置的2个server中有不相同的配置，所以在监听0.0.0.0_443中，会生成2个server，分别为httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io和httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io。
- 因为监听中生成2个server，所以在路由中会生成2条不同的路由相对应，在gateway的路由中生成分别的虚拟主机https.443.https-httpbina和https.443.https-httpbinb。
- 监听0.0.0.0_443所属的server httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io被关联至路由https.443.https-httpbina，server httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io被关联至路由https.443.https-httpbinb。
- 域名httpbin-a被路由至pod httpbin-a的/status uri。
- 域名httpbin-b被路由至pod httpbin-b的/headers uri。



### 相关配置

```bash
kubectl create -n istio-system secret tls istio-ingressgateway-httpbin-a-certs --key ./httpbin-a.key --cert ./httpbin-a.crt
kubectl create -n istio-system secret tls istio-ingressgateway-httpbin-b-certs --key ./httpbin-b.key --cert ./httpbin-b.crt
```

- k8s secret相关配置。



```bash
helm template install/kubernetes/helm/istio/ --name istio-ingressgateway --namespace istio-system -x charts/gateways/templates/deployment.yaml --set gateways.istio-egressgateway.enabled=false \
--set gateways.istio-ingressgateway.secretVolumes[0].name=ingressgateway-ca-certs \
--set gateways.istio-ingressgateway.secretVolumes[0].secretName=istio-ingressgateway-ca-certs \
--set gateways.istio-ingressgateway.secretVolumes[0].mountPath=/etc/istio/ingressgateway-ca-certs \
--set gateways.istio-ingressgateway.secretVolumes[1].name=ingressgateway-httpbin-a-certs \
--set gateways.istio-ingressgateway.secretVolumes[1].secretName=istio-ingressgateway-httpbin-a-certs \
--set gateways.istio-ingressgateway.secretVolumes[1].mountPath=/etc/istio/ingressgateway-httpbin-a-certs \
--set gateways.istio-ingressgateway.secretVolumes[2].name=ingressgateway-httpbin-b-certs \
--set gateways.istio-ingressgateway.secretVolumes[2].secretName=istio-ingressgateway-httpbin-b-certs \
--set gateways.istio-ingressgateway.secretVolumes[2].mountPath=/etc/istio/ingressgateway-httpbin-b-certs > \
./helm-ingressgateway.yaml

...
          volumeMounts:
          - name: istio-certs
            mountPath: /etc/certs
            readOnly: true
          - name: ingressgateway-ca-certs
            mountPath: "/etc/istio/ingressgateway-ca-certs"
            readOnly: true
          - name: ingressgateway-httpbin-a-certs
            mountPath: "/etc/istio/ingressgateway-httpbin-a-certs"
            readOnly: true
          - name: ingressgateway-httpbin-b-certs
            mountPath: "/etc/istio/ingressgateway-httpbin-b-certs"
            readOnly: true
      volumes:
      - name: istio-certs
        secret:
          secretName: istio.istio-ingressgateway-service-account
          optional: true
      - name: ingressgateway-ca-certs
        secret:
          secretName: "istio-ingressgateway-ca-certs"
          optional: true
      - name: ingressgateway-httpbin-a-certs
        secret:
          secretName: "istio-ingressgateway-httpbin-a-certs"
          optional: true
      - name: ingressgateway-httpbin-b-certs
        secret:
          secretName: "istio-ingressgateway-httpbin-b-certs"
          optional: true
...
```

- 修改了ingress gateway deployment的配置，可以支持多个证书。
- 分别包含域名为httpbin-a和httpbin-b的证书。

 

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpbin-dual-gateway-tls
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation
  servers:
  - port:
      number: 443
      name: https-httpbina
      protocol: HTTPS
    tls:
      mode: SIMPLE
      serverCertificate: /etc/istio/ingressgateway-httpbin-a-certs/tls.crt
      privateKey: /etc/istio/ingressgateway-httpbin-a-certs/tls.key
    hosts:
    - "httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io"
  - port:
      number: 443
      name: https-httpbinb
      protocol: HTTPS
    tls:
      mode: SIMPLE
      serverCertificate: /etc/istio/ingressgateway-httpbin-b-certs/tls.crt
      privateKey: /etc/istio/ingressgateway-httpbin-b-certs/tls.key
    hosts:
    - "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io"
```

- gateway相关配置。



```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin-a-vs
spec:
  hosts:
  - "httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io"
  gateways:
  - httpbin-dual-gateway-tls
  http:
  - match:
    - uri:
        prefix: /status
    route:
    - destination:
        port:
          number: 8000
        host: httpbin-a

apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin-b-vs
spec:
  hosts:
  - "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io"
  gateways:
  - httpbin-dual-gateway-tls
  http:
  - match:
    - uri:
        prefix: /headers
    route:
    - destination:
        port:
          number: 8000
        host: httpbin-b
```

- httpbin-a和httpbin-b的virtualservice相关配置。



```json
[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$ istioctl pc listener istio-ingressgateway-7ffb59776b-bn2sv -n istio-system -o json
[
    {
        "name": "0.0.0.0_443",
        "address": {
            "socketAddress": {
                "address": "0.0.0.0",
                "portValue": 443
            }
        },
        "filterChains": [
            {
                "filterChainMatch": {
                    "serverNames": [
                        "httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io"
                    ]
                },
                "tlsContext": {
                    "commonTlsContext": {
                        "tlsCertificates": [
                            {
                                "certificateChain": {
                                    "filename": "/etc/istio/ingressgateway-httpbin-a-certs/tls.crt"
                                },
                                "privateKey": {
                                    "filename": "/etc/istio/ingressgateway-httpbin-a-certs/tls.key"
                                }
                            }
                        ],
                        "alpnProtocols": [
                            "h2",
                            "http/1.1"
                        ]
                    },
                    "requireClientCertificate": false
                },
                "filters": [
                    {
                        "name": "envoy.http_connection_manager",
                        "config": {
                            "access_log": [
                                {
                                    "config": {
                                        "path": "/dev/stdout"
                                    },
                                    "name": "envoy.file_access_log"
                                }
                            ],
                            "generate_request_id": true,
                            "http_filters": [
                                {
                                    "config": {
                                        "default_destination_service": "default",
                                        "forward_attributes": {
                                            "attributes": {
                                                "source.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7ffb59776b-bn2sv.istio-system"
                                                }
                                            }
                                        },
                                        "mixer_attributes": {
                                            "attributes": {
                                                "context.reporter.kind": {
                                                    "string_value": "outbound"
                                                },
                                                "context.reporter.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7ffb59776b-bn2sv.istio-system"
                                                },
                                                "source.namespace": {
                                                    "string_value": "istio-system"
                                                },
                                                "source.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7ffb59776b-bn2sv.istio-system"
                                                }
                                            }
                                        },
                                        "service_configs": {
                                            "default": {}
                                        },
                                        "transport": {
                                            "attributes_for_mixer_proxy": {
                                                "attributes": {
                                                    "source.uid": {
                                                        "string_value": "kubernetes://istio-ingressgateway-7ffb59776b-bn2sv.istio-system"
                                                    }
                                                }
                                            },
                                            "check_cluster": "outbound|9091||istio-policy.istio-system.svc.cluster.local",
                                            "network_fail_policy": {
                                                "policy": "FAIL_CLOSE"
                                            },
                                            "report_cluster": "outbound|9091||istio-telemetry.istio-system.svc.cluster.local"
                                        }
                                    },
                                    "name": "mixer"
                                },
                                {
                                    "name": "envoy.cors"
                                },
                                {
                                    "name": "envoy.fault"
                                },
                                {
                                    "name": "envoy.router"
                                }
                            ],
                            "rds": {
                                "config_source": {
                                    "ads": {}
                                },
                                "route_config_name": "https.443.https-httpbina"
                            },
                            "stat_prefix": "0.0.0.0_443",
                            "stream_idle_timeout": "0.000s",
                            "tracing": {
                                "client_sampling": {
                                    "value": 100
                                },
                                "operation_name": "EGRESS",
                                "overall_sampling": {
                                    "value": 100
                                },
                                "random_sampling": {
                                    "value": 100
                                }
                            },
                            "upgrade_configs": [
                                {
                                    "upgrade_type": "websocket"
                                }
                            ],
                            "use_remote_address": true
                        }
                    }
                ]
            },
            {
                "filterChainMatch": {
                    "serverNames": [
                        "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io"
                    ]
                },
                "tlsContext": {
                    "commonTlsContext": {
                        "tlsCertificates": [
                            {
                                "certificateChain": {
                                    "filename": "/etc/istio/ingressgateway-httpbin-b-certs/tls.crt"
                                },
                                "privateKey": {
                                    "filename": "/etc/istio/ingressgateway-httpbin-b-certs/tls.key"
                                }
                            }
                        ],
                        "alpnProtocols": [
                            "h2",
                            "http/1.1"
                        ]
                    },
                    "requireClientCertificate": false
                },
                "filters": [
                    {
                        "name": "envoy.http_connection_manager",
                        "config": {
                            "access_log": [
                                {
                                    "config": {
                                        "path": "/dev/stdout"
                                    },
                                    "name": "envoy.file_access_log"
                                }
                            ],
                            "generate_request_id": true,
                            "http_filters": [
                                {
                                    "config": {
                                        "default_destination_service": "default",
                                        "forward_attributes": {
                                            "attributes": {
                                                "source.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7ffb59776b-bn2sv.istio-system"
                                                }
                                            }
                                        },
                                        "mixer_attributes": {
                                            "attributes": {
                                                "context.reporter.kind": {
                                                    "string_value": "outbound"
                                                },
                                                "context.reporter.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7ffb59776b-bn2sv.istio-system"
                                                },
                                                "source.namespace": {
                                                    "string_value": "istio-system"
                                                },
                                                "source.uid": {
                                                    "string_value": "kubernetes://istio-ingressgateway-7ffb59776b-bn2sv.istio-system"
                                                }
                                            }
                                        },
                                        "service_configs": {
                                            "default": {}
                                        },
                                        "transport": {
                                            "attributes_for_mixer_proxy": {
                                                "attributes": {
                                                    "source.uid": {
                                                        "string_value": "kubernetes://istio-ingressgateway-7ffb59776b-bn2sv.istio-system"
                                                    }
                                                }
                                            },
                                            "check_cluster": "outbound|9091||istio-policy.istio-system.svc.cluster.local",
                                            "network_fail_policy": {
                                                "policy": "FAIL_CLOSE"
                                            },
                                            "report_cluster": "outbound|9091||istio-telemetry.istio-system.svc.cluster.local"
                                        }
                                    },
                                    "name": "mixer"
                                },
                                {
                                    "name": "envoy.cors"
                                },
                                {
                                    "name": "envoy.fault"
                                },
                                {
                                    "name": "envoy.router"
                                }
                            ],
                            "rds": {
                                "config_source": {
                                    "ads": {}
                                },
                                "route_config_name": "https.443.https-httpbinb"
                            },
                            "stat_prefix": "0.0.0.0_443",
                            "stream_idle_timeout": "0.000s",
                            "tracing": {
                                "client_sampling": {
                                    "value": 100
                                },
                                "operation_name": "EGRESS",
                                "overall_sampling": {
                                    "value": 100
                                },
                                "random_sampling": {
                                    "value": 100
                                }
                            },
                            "upgrade_configs": [
                                {
                                    "upgrade_type": "websocket"
                                }
                            ],
                            "use_remote_address": true
                        }
                    }
                ]
            }
        ]
    }
]
[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$
```

- gateway envoy listener相关配置。



```json
[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$ istioctl pc route istio-ingressgateway-7ffb59776b-bn2sv -n istio-system -o json
[
    {
        "name": "https.443.https-httpbinb",
        "virtualHosts": [
            {
                "name": "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io:443",
                "domains": [
                    "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io",
                    "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io:443"
                ],
                "routes": [
                    {
                        "match": {
                            "prefix": "/headers"
                        },
                        "route": {
                            "cluster": "outbound|8000||httpbin-b.default.svc.cluster.local",
                            "timeout": "0.000s",
                            "maxGrpcTimeout": "0.000s"
                        },
                        "decorator": {
                            "operation": "httpbin-b.default.svc.cluster.local:8000/headers*"
                        },
                        "perFilterConfig": {
                            "mixer": {
                                "forward_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin-b.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin-b.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin-b"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin-b"
                                        }
                                    }
                                },
                                "mixer_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin-b.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin-b.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin-b"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin-b"
                                        }
                                    }
                                }
                            }
                        }
                    }
                ]
            }
        ],
        "validateClusters": false
    },
    {
        "name": "https.443.https-httpbina",
        "virtualHosts": [
            {
                "name": "httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io:443",
                "domains": [
                    "httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io",
                    "httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io:443"
                ],
                "routes": [
                    {
                        "match": {
                            "prefix": "/status"
                        },
                        "route": {
                            "cluster": "outbound|8000||httpbin-a.default.svc.cluster.local",
                            "timeout": "0.000s",
                            "maxGrpcTimeout": "0.000s"
                        },
                        "decorator": {
                            "operation": "httpbin-a.default.svc.cluster.local:8000/status*"
                        },
                        "perFilterConfig": {
                            "mixer": {
                                "forward_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin-a.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin-a.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin-a"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin-a"
                                        }
                                    }
                                },
                                "mixer_attributes": {
                                    "attributes": {
                                        "destination.service": {
                                            "string_value": "httpbin-a.default.svc.cluster.local"
                                        },
                                        "destination.service.host": {
                                            "string_value": "httpbin-a.default.svc.cluster.local"
                                        },
                                        "destination.service.name": {
                                            "string_value": "httpbin-a"
                                        },
                                        "destination.service.namespace": {
                                            "string_value": "default"
                                        },
                                        "destination.service.uid": {
                                            "string_value": "istio://default/services/httpbin-a"
                                        }
                                    }
                                }
                            }
                        }
                    }
                ]
            }
        ],
        "validateClusters": false
    }
]
[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$
```

- gateway envoy route相关配置。



```bash
[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$ http https://httpbin-a.7cb9a9b7b318440399a0.eastus.aksapp.io/status/418 --verify no
HTTP/1.1 418 Unknown
access-control-allow-credentials: true
access-control-allow-origin: *
content-length: 135
date: Fri, 12 Oct 2018 06:57:00 GMT
server: envoy
x-envoy-upstream-service-time: 3
x-more-info: http://tools.ietf.org/html/rfc2324

    -=[ teapot ]=-

       _...._
     .'  _ _ `.
    | ."` ^ `". _,
    \_;`"---"`|//
      |       ;/
      \_     _/
        `"""`

[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$ http https://httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io/headers --verify no
HTTP/1.1 200 OK
access-control-allow-credentials: true
access-control-allow-origin: *
content-length: 1012
content-type: application/json
date: Fri, 12 Oct 2018 06:57:36 GMT
server: envoy
x-envoy-upstream-service-time: 2

{
    "headers": {
        "Accept": "*/*",
        "Accept-Encoding": "gzip, deflate",
        "Content-Length": "0",
        "Host": "httpbin-b.7cb9a9b7b318440399a0.eastus.aksapp.io",
        "User-Agent": "HTTPie/0.9.9",
        "X-B3-Sampled": "1",
        "X-B3-Spanid": "fe78e8beb078cc13",
        "X-B3-Traceid": "fe78e8beb078cc13",
        "X-Envoy-Decorator-Operation": "httpbin-b.default.svc.cluster.local:8000/headers*",
        "X-Envoy-Internal": "true",
        "X-Istio-Attributes": "Ck8KCnNvdXJjZS51aWQSQRI/a3ViZXJuZXRlczovL2lzdGlvLWluZ3Jlc3NnYXRld2F5LTdmZmI1OTc3NmItYm4yc3YuaXN0aW8tc3lzdGVtCjwKE2Rlc3RpbmF0aW9uLnNlcnZpY2USJRIjaHR0cGJpbi1iLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwKPwoXZGVzdGluYXRpb24uc2VydmljZS51aWQSJBIiaXN0aW86Ly9kZWZhdWx0L3NlcnZpY2VzL2h0dHBiaW4tYgpBChhkZXN0aW5hdGlvbi5zZXJ2aWNlLmhvc3QSJRIjaHR0cGJpbi1iLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwKKgodZGVzdGluYXRpb24uc2VydmljZS5uYW1lc3BhY2USCRIHZGVmYXVsdAonChhkZXN0aW5hdGlvbi5zZXJ2aWNlLm5hbWUSCxIJaHR0cGJpbi1i",
        "X-Request-Id": "6ecf52bb-212e-98c2-88b3-0b81ab247360"
    }
}

[~/K8s/istio/istio-azure-1.0.2/samples/httpbin]$

```

- 测试结果。

