package com.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@SpringBootApplication
@RestController
public class DemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }

    // Simple endpoint to verify the deployment works end-to-end
    @GetMapping("/api/inventory")
    public Map<String, Object> inventory() {
        return Map.of(
                "service", "inventory-demo",
                "status", "UP",
                "version", System.getenv().getOrDefault("APP_VERSION", "local")
        );
    }
}
