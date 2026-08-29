#import "@preview/modern-cv:0.10.0": *

#show: resume.with(
  author: (
    firstname: "Nakorn Boon Han",
    lastname: "Charayaphan",
    email: "charayaphan.nakorn.boon.han@gmail.com",
    phone: "(+65) 8849 1870",
    github: "cnboonhan",
    linkedin: "nakorn-boon-han-charayaphan-048bb3151",
    address: "Singapore",
    positions: (
      "Lead Engineer",
      "Physical AI",
    ),
  ),
  keywords: ("Platform Engineering", "Kubernetes", "OpenShift", "AWS", "Physical AI"),
  description: "Resume of Charayaphan Nakorn Boon Han",
  profile-picture: none,
  date: datetime.today().display(),
  language: "en",
  font: ("Source Sans 3",),
  colored-headers: true,
  show-footer: false,
  show-address-icon: true,
  paper-size: "us-letter",
  contact-items-separator: box[#h(2pt)#text("|")#h(2pt)],
)

#include "sections/experience.typ"
#include "sections/projects.typ"
#include "sections/skills.typ"
#include "sections/education.typ"
#include "sections/certifications.typ"
