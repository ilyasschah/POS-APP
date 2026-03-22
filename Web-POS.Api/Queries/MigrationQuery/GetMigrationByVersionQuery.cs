using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.MigrationQuery
{
    public class GetMigrationByVersionQuery : IRequest<MigrationDto?>
    {
        public string Version { get; set; } = default!;

        public class GetMigrationByVersionQueryHandler : IRequestHandler<GetMigrationByVersionQuery, MigrationDto?>
        {
            private readonly MigrationRepository _repository;

            public GetMigrationByVersionQueryHandler(MigrationRepository repository)
            {
                _repository = repository;
            }

            public async Task<MigrationDto?> Handle(GetMigrationByVersionQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByVersionAsync(request.Version);
                return entity == null ? null : MapperMigration.MapToMigrationDto(entity);
            }
        }
    }
}
