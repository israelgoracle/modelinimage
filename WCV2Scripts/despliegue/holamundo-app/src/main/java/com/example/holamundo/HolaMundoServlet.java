package com.example.holamundo;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.PrintWriter;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class HolaMundoServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("text/html;charset=UTF-8");

        LocalDateTime now = LocalDateTime.now();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss");
        String fechaActual = now.format(formatter);

        try (PrintWriter out = response.getWriter()) {
            out.println("<!DOCTYPE html>");
            out.println("<html>");
            out.println("<head>");
            out.println("<title>Hola Mundo</title>");
            out.println("<meta charset='UTF-8'>");
            out.println("<style>");
            out.println("body { font-family: Arial, sans-serif; margin: 50px; text-align: center; }");
            out.println("h1 { color: #333; }");
            out.println("p { color: #666; font-size: 18px; }");
            out.println("</style>");
            out.println("</head>");
            out.println("<body>");
            out.println("<h1>Hola Mundo</h1>");
            out.println("<p>Fecha actual: " + fechaActual + "</p>");
            out.println("</body>");
            out.println("</html>");
        }
    }
}
