create or replace PACKAGE national_id_number_utils_pkg AS
  FUNCTION validate(p_national_id_number VARCHAR2
                   ,p_country_code       VARCHAR2) RETURN BOOLEAN;

  FUNCTION get_birth_date(p_national_id_number VARCHAR2
                         ,p_country_code       VARCHAR2) RETURN DATE;

  FUNCTION get_gender(p_national_id_number VARCHAR2
                     ,p_country_code       VARCHAR2) RETURN VARCHAR2;
END national_id_number_utils_pkg;
/