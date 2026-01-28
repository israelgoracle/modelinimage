# Aplicación Hola Mundo J2EE

Aplicación web simple en J2EE con Java 17 que muestra "Hola Mundo" y la fecha actual.

## Requisitos

- Java 17
- Maven 3.6+
- Servidor de aplicaciones compatible con Jakarta EE 9+ (Tomcat 10+, WildFly 26+, etc.)

## Compilación

```bash
mvn clean package
```

Esto generará el archivo WAR en `target/holamundo.war`

## Despliegue

### En Tomcat 10

1. Copia el archivo `target/holamundo.war` al directorio `webapps` de Tomcat
2. Inicia Tomcat
3. Accede a: `http://localhost:8080/holamundo/`

### En WildFly

1. Copia el archivo `target/holamundo.war` al directorio `standalone/deployments`
2. Inicia WildFly
3. Accede a: `http://localhost:8080/holamundo/`

## Estructura del Proyecto

```
holamundo-app/
├── pom.xml
├── src/
│   └── main/
│       ├── java/
│       │   └── com/
│       │       └── example/
│       │           └── holamundo/
│       │               └── HolaMundoServlet.java
│       └── webapp/
│           └── WEB-INF/
│               └── web.xml
```

## Características

- Muestra "Hola Mundo" en una página HTML
- Muestra la fecha y hora actual en formato DD/MM/YYYY HH:mm:ss
- Utiliza Jakarta Servlet API 5.0
- Compatible con Java 17
