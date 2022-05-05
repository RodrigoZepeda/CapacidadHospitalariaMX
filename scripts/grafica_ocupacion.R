pacman::p_load(tidyverse, glue, lubridate, zoo, ggtext)

#Gráfica de ocupación
read_csv("processed/HospitalizacionesMX_estatal.csv",
         show_col_types = F) %>%
  pivot_longer(cols = `Hospitalizados (%)`:`UCI y Ventilación (%)`,
               names_to = "Tipo de pacientes", 
               values_to = "Ocupación (%)") %>%
  arrange(Fecha, Estado, `Tipo de pacientes`) %>%
  group_by(Estado, `Tipo de pacientes`) %>%
  mutate(Smooth = rollmean(
    rollmean(`Ocupación (%)`, 7, fill = 0, align = "right"), 
    7, fill = 0, align = "right")) %>%
  filter(`Tipo de pacientes` == "Hospitalizados (%)") %>%
  mutate(Estado = if_else(str_detect(Estado,"Veracruz"), 
                          "Veracruz de\nIgnacio de la Llave", Estado)) %>%
  ggplot() +
  geom_ribbon(aes(x = Fecha, ymin = 0, ymax = `Smooth`/100), fill = "#de6600",
              color = "black", size = 0.5) +
  facet_wrap(~Estado, ncol = 4) +
  labs(
    y = "<span style = 'color:#de6600;'>Ocupación</span> de la Red IRAG",
    x = "",
    title    = glue("Porcentaje de ",
                    "<span style = 'color:#de6600;'>ocupación</span>", 
                    " de la Red de Infecciones Respiratorias Agudas Graves de México (IRAG)"),
    caption  = glue("Zepeda-Tello, Rodrigo. Repositorio de datos de COVID-19 en México.",
                    "Open Science Framework. DOI 10.17605/OSF.IO/9NU2D"),
    subtitle = glue("<span style = 'color:#007a7a;'>Sistema de Información de la Red IRAG ",
                    "(actualizado el {today()})</span>")
  ) +
  theme_minimal() +
  scale_y_continuous(labels = scales::percent, limits = c(0,1), expand = c(0,0)) +
  scale_x_date(expand = c(0,0), date_labels = "%b-%y", date_breaks = "4 months") +
  theme(legend.position  = "top",
        #text = element_text(family = "Times", color = "black"),
        plot.title       = element_markdown(),
        plot.subtitle    = element_markdown(face = "italic"),
        panel.spacing    = unit(1, "lines"),
        panel.grid       = element_blank(),
        axis.title.y     = element_markdown(color = "black"),
        panel.background = element_rect(fill = "#007a7a"),
        plot.background  = element_rect(fill = alpha("#ebd9c8", 0.1)),
        axis.text        = element_text(color = "black"),
        axis.text.x      = element_text(angle = 90, size = 7, hjust = 1),
        panel.border     = element_rect(color = "black", fill = NA, size = 1))
ggsave("docs/images/Ocupacion_hospitalaria.png", width = 9, height = 14, bg = "white", dpi = 750)
ggsave("docs/images/Ocupacion_hospitalaria.pdf", width = 9, height = 14)
