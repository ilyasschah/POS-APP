using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.UserQuery;

public class GetAllUsersQuery : IRequest<List<UserDto>>
{
    public int CompanyId { get; set; }

    public class GetAllUsersQueryHandler : IRequestHandler<GetAllUsersQuery, List<UserDto>>
    {
        private readonly UserRepository _repository;

        public GetAllUsersQueryHandler(UserRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<UserDto>> Handle(GetAllUsersQuery request, CancellationToken cancellationToken)
        {
            var entities = await _repository.GetAllAsync(request.CompanyId);
            return entities.Select(MapperUser.MapToUserDto).ToList();
        }
    }
    public class GetAllUsersQueryValidator : AbstractValidator<GetAllUsersQuery>
    {
        public GetAllUsersQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
