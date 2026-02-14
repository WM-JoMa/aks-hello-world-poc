FROM eclipse-temurin:17
COPY HelloWorld.java /usr/src/myapp/HelloWorld.java
WORKDIR /usr/src/myapp
RUN javac HelloWorld.java
EXPOSE 8080
ENV PORT=8080
CMD ["java", "HelloWorld"]
