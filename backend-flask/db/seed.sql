INSERT INTO public.users (display_name, email, handle, cognito_user_id)
VALUES
  ('Andrew Brown', 'animerat+abrown@gmail.com','andrewbrown' ,'MOCK'),
  ('Rusty', 'animerat+rusty@gmail.com','Rusty','MOCK'),
  ('Andrew Bayko', 'animerat+bayko@gmail.com', 'bayko' ,'MOCK'),
  ('Londo Mollari', 'animerat+londo@gmail.com', 'londo', 'MOCK');

INSERT INTO public.activities (user_uuid, message, expires_at)
VALUES
  (
    (SELECT uuid from public.users WHERE users.handle = 'andrewbrown' LIMIT 1),
    'This was imported as seed data!',
    current_timestamp + interval '10 day'
  );