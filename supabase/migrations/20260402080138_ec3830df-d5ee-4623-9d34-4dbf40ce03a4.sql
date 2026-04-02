
-- Create a security definer function to check owner role (avoids infinite recursion)
CREATE OR REPLACE FUNCTION public.is_owner(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = 'owner'
  );
$$;

-- Drop the problematic policies
DROP POLICY IF EXISTS "Owners can manage roles" ON public.user_roles;
DROP POLICY IF EXISTS "Owners can manage permissions" ON public.user_permissions;

-- Recreate without recursion
CREATE POLICY "Owners can manage roles"
ON public.user_roles
FOR ALL
TO authenticated
USING (public.is_owner(auth.uid()))
WITH CHECK (public.is_owner(auth.uid()));

CREATE POLICY "Owners can manage permissions"
ON public.user_permissions
FOR ALL
TO authenticated
USING (public.is_owner(auth.uid()))
WITH CHECK (public.is_owner(auth.uid()));

-- Insert owner role for the existing user
INSERT INTO public.user_roles (user_id, role)
VALUES ('f37fa1e1-70d5-4bb8-9d55-2477d0d1ffdc', 'owner')
ON CONFLICT DO NOTHING;
