CREATE OR REPLACE PACKAGE BODY national_id_number_api_pkg IS

  c_latvia_country_code    CONSTANT VARCHAR2(2) := 'LV';
  c_lithuania_country_code CONSTANT VARCHAR2(2) := 'LT';
  c_male_code              CONSTANT VARCHAR2(1) := 'M';
  c_female_code            CONSTANT VARCHAR2(1) := 'F';

  FUNCTION calculate_checksum_lv(p_national_id_number VARCHAR2) RETURN NUMBER IS
    CURSOR c_national_id_number_digits(p_national_id_number_no_dash VARCHAR2) IS
      SELECT *
        FROM (SELECT 'digit_' || LEVEL digit_id
                    ,to_number(substr(p_national_id_number_no_dash, LEVEL, 1)) digit
                FROM dual
              CONNECT BY LEVEL <= length(p_national_id_number_no_dash))
      pivot(MIN(digit)
         FOR digit_id IN('digit_1' AS digit_1
                        ,'digit_2' AS digit_2
                        ,'digit_3' AS digit_3
                        ,'digit_4' AS digit_4
                        ,'digit_5' AS digit_5
                        ,'digit_6' AS digit_6
                        ,'digit_7' AS digit_7
                        ,'digit_8' AS digit_8
                        ,'digit_9' AS digit_9
                        ,'digit_10' AS digit_10
                        ,'digit_11' AS digit_11));
  
    l_checksum_formula_sql VARCHAR2(155) := 'SELECT mod(mod((1101-(1*:digit_1+6*:digit_2+3*:digit_3+7*:digit_4+9*:digit_5+10*:digit_6+5*:digit_7+8*:digit_8+4*:digit_9+2*:digit_10)), 11), 10) FROM dual';
    l_checksum_result      NUMBER;
  BEGIN
    FOR i IN c_national_id_number_digits(p_national_id_number_no_dash => REPLACE(p_national_id_number, '-')) LOOP
      EXECUTE IMMEDIATE l_checksum_formula_sql
        INTO l_checksum_result
        USING i.digit_1, i.digit_2, i.digit_3, i.digit_4, i.digit_5, i.digit_6, i.digit_7, i.digit_8, i.digit_9, i.digit_10;
    END LOOP;
  
    RETURN l_checksum_result;
  END calculate_checksum_lv;

  FUNCTION validate_lv(p_national_id_number VARCHAR2) RETURN BOOLEAN IS
    l_is_valid    BOOLEAN;
    l_check_digit VARCHAR2(1);
  BEGIN
  
    IF length(p_national_id_number) = 12 AND regexp_like(p_national_id_number, '(\d{6})-(\d{5})') THEN
      l_check_digit := substr(p_national_id_number, -1, 1);
    
      IF calculate_checksum_lv(p_national_id_number) = l_check_digit THEN
        l_is_valid := TRUE;
      ELSE
        dbms_output.put_line('Invalid code: checksum result does not match check digit.');
        l_is_valid := FALSE;
      END IF;
    
    ELSE
      dbms_output.put_line('Invalid code format. Should be 999999-99999.');
      l_is_valid := FALSE;
    END IF;
  
    RETURN l_is_valid;
  END validate_lv;

  FUNCTION calculate_checksum_lt(p_national_id_number VARCHAR2) RETURN NUMBER IS
    CURSOR c_national_id_number_digits(p_national_id_number VARCHAR2) IS
      SELECT LEVEL digit_id
            ,to_number(substr(p_national_id_number, LEVEL, 1)) digit
        FROM dual
      CONNECT BY LEVEL <= length(p_national_id_number)
             AND rownum < 11;
  
    l_checksum_result_1     NUMBER := 0;
    l_checksum_result_2     NUMBER := 0;
    l_checksum_result_final NUMBER := 0;
    l_start_multiplier_1    NUMBER := 1;
    l_start_multiplier_2    NUMBER := 3;
  BEGIN
    FOR i IN c_national_id_number_digits(p_national_id_number => p_national_id_number) LOOP
      l_checksum_result_1 := l_checksum_result_1 + i.digit * l_start_multiplier_1;
      l_checksum_result_2 := l_checksum_result_2 + i.digit * l_start_multiplier_2;
    
      l_start_multiplier_1 := l_start_multiplier_1 + 1;
      l_start_multiplier_2 := l_start_multiplier_2 + 1;
    
      IF l_start_multiplier_1 = 10 THEN
        l_start_multiplier_1 := 1;
      END IF;
    
      IF l_start_multiplier_2 = 10 THEN
        l_start_multiplier_2 := 1;
      END IF;
    END LOOP;
  
    l_checksum_result_1 := MOD(l_checksum_result_1, 11);
    l_checksum_result_2 := MOD(l_checksum_result_2, 11);
  
    IF l_checksum_result_1 < 10 THEN
      l_checksum_result_final := l_checksum_result_1;
    ELSIF l_checksum_result_2 < 10 THEN
      l_checksum_result_final := l_checksum_result_2;
    ELSE
      l_checksum_result_final := 0;
    END IF;
    dbms_output.put_line(l_checksum_result_final);
    RETURN l_checksum_result_final;
  END calculate_checksum_lt;

  FUNCTION validate_lt(p_national_id_number VARCHAR2) RETURN BOOLEAN IS
    CURSOR c_national_id_number_digits(p_national_id_nr_no_spaces VARCHAR2) IS
      SELECT LEVEL digit_id
            ,to_number(substr(p_national_id_nr_no_spaces, LEVEL, 1)) digit
        FROM dual
      CONNECT BY LEVEL <= length(p_national_id_nr_no_spaces);
  
    l_is_valid    BOOLEAN;
    l_check_digit NUMBER;
    l_first_digit NUMBER;
  BEGIN
  
    IF length(p_national_id_number) = 11 AND regexp_like(p_national_id_number, '(\d{11})') THEN
      l_first_digit := to_number(substr(p_national_id_number, 0, 1));
    
      IF l_first_digit = 9 THEN
        dbms_output.put_line('Exceptional case: code starting with 9.');
        l_is_valid := TRUE;
      ELSE
      
        l_check_digit := to_number(substr(p_national_id_number, -1, 1));
      
        IF get_birth_date(p_national_id_number, c_lithuania_country_code) IS NOT NULL THEN
          IF get_gender(p_national_id_number, c_lithuania_country_code) IS NOT NULL THEN
            IF calculate_checksum_lt(p_national_id_number) = l_check_digit THEN
              l_is_valid := TRUE;
            ELSE
              dbms_output.put_line('Invalid code: checksum result does not match check digit.');
              l_is_valid := FALSE;
            END IF;
          ELSE
            dbms_output.put_line('Invalid code: gender and birth century is wrong. Valid numbers are 1, 2, 3, 4, 5 and 6.');
            l_is_valid := FALSE;
          END IF;
        ELSE
          dbms_output.put_line('Invalid code: birthday part is in wrong format. Should be YYMMDD. First digit should be 1, 2, 3, 4, 5 or 6.');
          l_is_valid := FALSE;
        END IF;
      END IF;
    
    ELSE
      dbms_output.put_line('Invalid code format. Should be 99999999999.');
      l_is_valid := FALSE;
    END IF;
  
    RETURN l_is_valid;
  END validate_lt;

  FUNCTION validate(p_national_id_number VARCHAR2
                   ,p_country_code       VARCHAR2) RETURN BOOLEAN IS
    l_is_valid BOOLEAN;
  BEGIN
    dbms_output.put_line('Valindating code: ' || p_national_id_number);
    IF p_country_code = c_latvia_country_code THEN
      l_is_valid := validate_lv(p_national_id_number => p_national_id_number);
    ELSIF p_country_code = c_lithuania_country_code THEN
      l_is_valid := validate_lt(p_national_id_number => p_national_id_number);
    
      RETURN l_is_valid;
    END IF;
  
    RETURN l_is_valid;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('Error validating national id number: ');
      dbms_output.put_line(dbms_utility.format_error_stack);
      dbms_output.put_line(dbms_utility.format_error_backtrace);
      l_is_valid := FALSE;
      RETURN l_is_valid;
  END validate;

  FUNCTION get_year_2_start_digits_lv(p_national_id_number VARCHAR2) RETURN VARCHAR2 IS
    l_year_2_start_digits VARCHAR2(2);
    l_check_digit         VARCHAR2(1);
  BEGIN
    l_check_digit         := substr(p_national_id_number, instr(p_national_id_number, '-') + 1, 1);
    l_year_2_start_digits := CASE l_check_digit
                               WHEN '0' THEN
                                '18'
                               WHEN '1' THEN
                                '19'
                               WHEN '2' THEN
                                '20'
                             END;
  
    RETURN l_year_2_start_digits;
  EXCEPTION
    WHEN OTHERS THEN
      l_year_2_start_digits := NULL;
    
      RETURN l_year_2_start_digits;
  END get_year_2_start_digits_lv;

  FUNCTION get_year_2_start_digits_lt(p_national_id_number VARCHAR2) RETURN VARCHAR2 IS
    l_year_2_start_digits VARCHAR2(2);
    l_check_digit         VARCHAR2(1);
  BEGIN
    l_check_digit         := substr(p_national_id_number, 0, 1);
    l_year_2_start_digits := CASE
                               WHEN l_check_digit IN ('1', '2') THEN
                                '18'
                               WHEN l_check_digit IN ('3', '4') THEN
                                '19'
                               WHEN l_check_digit IN ('5', '6') THEN
                                '20'
                             END;
  
    RETURN l_year_2_start_digits;
  EXCEPTION
    WHEN OTHERS THEN
      l_year_2_start_digits := NULL;
    
      RETURN l_year_2_start_digits;
  END get_year_2_start_digits_lt;

  FUNCTION get_birth_date_lv(p_national_id_number VARCHAR2) RETURN DATE IS
  
    l_birth_date                  DATE;
    l_extracted_birth_date_string VARCHAR2(6);
    l_year_2_start_digits         VARCHAR2(2);
    l_year_2_end_digits           VARCHAR2(4);
  
    l_birth_date_day             VARCHAR2(2);
    l_birth_date_month           VARCHAR2(2);
    l_complete_birth_date_string VARCHAR2(8);
  BEGIN
    l_extracted_birth_date_string := substr(p_national_id_number, 0, instr(p_national_id_number, '-') - 1);
    l_birth_date_day              := substr(l_extracted_birth_date_string, 0, 2);
    l_birth_date_month            := substr(l_extracted_birth_date_string, 3, 2);
    l_year_2_end_digits           := substr(l_extracted_birth_date_string, 5, 2);
  
    l_year_2_start_digits := get_year_2_start_digits_lv(p_national_id_number => p_national_id_number);
  
    IF l_year_2_start_digits IS NOT NULL THEN
      l_complete_birth_date_string := l_birth_date_day || l_birth_date_month || l_year_2_start_digits || l_year_2_end_digits;
      l_birth_date                 := to_date(l_complete_birth_date_string, 'DDMMYYYY');
    ELSE
      l_birth_date := NULL;
    END IF;
  
    RETURN l_birth_date;
  END get_birth_date_lv;

  FUNCTION get_birth_date_lt(p_national_id_number VARCHAR2) RETURN DATE IS
  
    l_birth_date                  DATE;
    l_extracted_birth_date_string VARCHAR2(6);
    l_year_2_start_digits         VARCHAR2(2);
    l_year_2_end_digits           VARCHAR2(4);
  
    l_birth_date_day             VARCHAR2(2);
    l_birth_date_month           VARCHAR2(2);
    l_complete_birth_date_string VARCHAR2(8);
  BEGIN
    l_extracted_birth_date_string := substr(p_national_id_number, 2, 6);
    l_birth_date_day              := substr(l_extracted_birth_date_string, 5, 2);
    l_birth_date_month            := substr(l_extracted_birth_date_string, 3, 2);
    l_year_2_end_digits           := substr(l_extracted_birth_date_string, 0, 2);
  
    l_year_2_start_digits := get_year_2_start_digits_lt(p_national_id_number => p_national_id_number);
  
    IF l_year_2_start_digits IS NOT NULL THEN
      l_complete_birth_date_string := l_birth_date_day || l_birth_date_month || l_year_2_start_digits || l_year_2_end_digits;
      l_birth_date                 := to_date(l_complete_birth_date_string, 'DDMMYYYY');
    ELSE
      l_birth_date := NULL;
    END IF;
  
    RETURN l_birth_date;
  END get_birth_date_lt;

  FUNCTION get_birth_date(p_national_id_number VARCHAR2
                         ,p_country_code       VARCHAR2) RETURN DATE IS
    l_birth_date                  DATE;
    l_extracted_birth_date_string VARCHAR2(6);
    l_year_2_start_digits         VARCHAR2(2);
    l_year_2_end_digits           VARCHAR2(4);
  
    l_birth_date_day             VARCHAR2(2);
    l_birth_date_month           VARCHAR2(2);
    l_complete_birth_date_string VARCHAR2(8);
  BEGIN
    IF p_country_code = c_latvia_country_code THEN
      l_birth_date := get_birth_date_lv(p_national_id_number);
    ELSIF p_country_code = c_lithuania_country_code THEN
      l_birth_date := get_birth_date_lt(p_national_id_number);
    END IF;
  
    RETURN l_birth_date;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('Error in getting birth date from national id number: ');
      dbms_output.put_line(dbms_utility.format_error_stack);
      dbms_output.put_line(dbms_utility.format_error_backtrace);
      l_birth_date := NULL;
    
      RETURN l_birth_date;
  END get_birth_date;

  FUNCTION get_gender_lt(p_national_id_number VARCHAR2) RETURN VARCHAR2 IS
  
    l_gender       VARCHAR2(1);
    l_gender_digit NUMBER;
  BEGIN
    l_gender_digit := to_number(substr(p_national_id_number, 0, 1));
  
    IF l_gender_digit >= 1 AND l_gender_digit <= 6 THEN
      l_gender := CASE MOD(l_gender_digit, 2)
                    WHEN 1 THEN
                     c_male_code
                    WHEN 0 THEN
                     c_female_code
                  END;
    END IF;
  
    RETURN l_gender;
  END get_gender_lt;

  FUNCTION get_gender(p_national_id_number VARCHAR2
                     ,p_country_code       VARCHAR2) RETURN VARCHAR2 IS
    l_gender VARCHAR2(1);
  BEGIN
    IF p_country_code = c_lithuania_country_code THEN
      l_gender := get_gender_lt(p_national_id_number);
    ELSE
      l_gender := NULL;
    END IF;
  
    RETURN l_gender;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('Error in getting gender from national id number: ');
      dbms_output.put_line(dbms_utility.format_error_stack);
      dbms_output.put_line(dbms_utility.format_error_backtrace);
      l_gender := NULL;
    
      RETURN l_gender;
  END get_gender;

END national_id_number_api_pkg;
/