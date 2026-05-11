using FluentValidation;
using MediatR;
using Api.Repository;
using Api.Models;

namespace Api.Queries.UserQuery;

public class GetAllUsersQuery : IRequest<List<UserDto>>
{
    public int CompanyId { get; set; }
    public string? DeviceId { get; set; }

    public class GetAllUsersQueryHandler : IRequestHandler<GetAllUsersQuery, List<UserDto>>
    {
        private readonly UserRepository _repository;

        public GetAllUsersQueryHandler(UserRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<UserDto>> Handle(GetAllUsersQuery request, CancellationToken cancellationToken)
        {
            return await _repository.GetAllUsersAsync(request.CompanyId, request.DeviceId);
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