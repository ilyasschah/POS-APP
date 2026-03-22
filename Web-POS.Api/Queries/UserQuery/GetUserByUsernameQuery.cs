using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.UserQuery;

public class GetUserByUsernameQuery : IRequest<UserDto?>
{
    public string Username { get; }
    public int CompanyId { get; set; }
    public GetUserByUsernameQuery(string username) { Username = username; }

    public class GetUserByUsernameQueryHandler : IRequestHandler<GetUserByUsernameQuery, UserDto?>
    {
        private readonly UserRepository _repository;

        public GetUserByUsernameQueryHandler(UserRepository repository)
        {
            _repository = repository;
        }

        public async Task<UserDto?> Handle(GetUserByUsernameQuery request, CancellationToken cancellationToken)
        {
            var entity = await _repository.GetByUsernameAsync(request.Username, request.CompanyId);
            return entity == null ? null : MapperUser.MapToUserDto(entity);
        }
    }
    public class GetUserByUsernameQueryValidator : AbstractValidator<GetUserByUsernameQuery>
    {
        public GetUserByUsernameQueryValidator()
        {
            RuleFor(x => x.Username).NotEmpty().WithMessage("Username must not be empty.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
